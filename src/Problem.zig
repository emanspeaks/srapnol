//! Problem definition for `srapnol`: minimize `F[obj_row](x) + obj_add`
//! subject to `x_low <= x <= x_upp` and `f_low <= F(x) <= f_upp`, with
//! `F(x) = f(x) + A x`. The callback evaluates only the nonlinear part
//! `f(x)` and its sparse Jacobian `G`; the solver adds `A x` itself.
//! Indices are 0-based. Contract: `docs/SUM.md`; requirements SRS-001 and
//! SRS section 2.1.

const std = @import("std");
const Problem = @This();

/// Bounds at or beyond this magnitude are infinite (SRS-006).
pub const infinity: f64 = 1.0e20;

/// Sparse coordinate pattern: any order, 0-based, no duplicates.
pub const Pattern = struct {
    rows: []const u32 = &.{},
    cols: []const u32 = &.{},

    pub fn len(self: Pattern) usize {
        return self.rows.len;
    }
};

/// Constant linear part `A` as coordinate triplets.
pub const Linear = struct {
    rows: []const u32 = &.{},
    cols: []const u32 = &.{},
    vals: []const f64 = &.{},

    pub fn len(self: Linear) usize {
        return self.rows.len;
    }
};

/// Where in the solve a callback happens; mirrors snOptA's `Status` (SRS-020).
pub const Status = enum {
    /// First call; a good place for one-time setup.
    first,
    normal,
    /// Final call at the solution; nothing further is read from `f`/`g`.
    last,
};

pub const EvalError = error{
    /// `f` is undefined at `x`; the solver retries with a shorter step (SRS-022).
    Undefined,
    /// Stop the solve; reported as `Exit.user_terminated` (SRS-024).
    Abort,
};

/// One evaluation request. `f` and `g` are null when not needed.
pub const Request = struct {
    /// Current point, length `n`.
    x: []const f64,
    /// Output: nonlinear part `f(x)` only, length `nf`. Rows that are
    /// entirely linear get zero.
    f: ?[]f64,
    /// Output: Jacobian of `f`, one value per `g` pattern entry, in
    /// pattern order.
    g: ?[]f64,
    status: Status,
};

pub const EvalFn = *const fn (ctx: ?*anyopaque, req: Request) EvalError!void;

/// Number of variables.
n: usize,
/// Number of problem functions, objective row included.
nf: usize,
/// Row of `F` holding the objective; null asks only for a feasible point.
obj_row: ?u32 = null,
/// Constant added to the objective; reporting only.
obj_add: f64 = 0,
x_low: []const f64,
x_upp: []const f64,
f_low: []const f64,
f_upp: []const f64,
a: Linear = .{},
g: Pattern = .{},
eval: EvalFn,
ctx: ?*anyopaque = null,
name: []const u8 = "",

/// Adapts a typed `fn (*Ctx, Request) EvalError!void` to `EvalFn` (SRS-075).
pub fn wrap(comptime Ctx: type, comptime func: anytype) EvalFn {
    return struct {
        fn thunk(ctx: ?*anyopaque, req: Request) EvalError!void {
            const p: *Ctx = @ptrCast(@alignCast(ctx.?));
            return func(p, req);
        }
    }.thunk;
}

pub fn evaluate(self: *const Problem, x: []const f64, f: ?[]f64, g: ?[]f64, status: Status) EvalError!void {
    return self.eval(self.ctx, .{ .x = x, .f = f, .g = g, .status = status });
}

/// `f += A x`; turns the callback's `f(x)` into the full `F(x)` (SRS-005).
pub fn addLinear(self: *const Problem, x: []const f64, f: []f64) void {
    for (self.a.rows, self.a.cols, self.a.vals) |i, j, v| f[i] += v * x[j];
}

pub fn isInfinite(bound: f64) bool {
    return @abs(bound) >= infinity;
}

pub const ValidateError = error{
    NoVariables,
    NoFunctions,
    LengthMismatch,
    InvertedBounds,
    NonFiniteValue,
    ObjRowOutOfRange,
    IndexOutOfRange,
    DuplicateEntry,
    OverlappingEntry,
    OutOfMemory,
};

/// Structural checks (SRS-009). Scratch space is only for the duplicate scan.
pub fn validate(self: *const Problem, allocator: std.mem.Allocator) ValidateError!void {
    if (self.n == 0) return error.NoVariables;
    if (self.nf == 0) return error.NoFunctions;
    if (self.x_low.len != self.n or self.x_upp.len != self.n) return error.LengthMismatch;
    if (self.f_low.len != self.nf or self.f_upp.len != self.nf) return error.LengthMismatch;
    if (self.a.cols.len != self.a.rows.len or self.a.vals.len != self.a.rows.len) return error.LengthMismatch;
    if (self.g.cols.len != self.g.rows.len) return error.LengthMismatch;
    try checkBounds(self.x_low, self.x_upp);
    try checkBounds(self.f_low, self.f_upp);
    if (self.obj_row) |r| if (r >= self.nf) return error.ObjRowOutOfRange;
    for (self.a.vals) |v| if (!std.math.isFinite(v)) return error.NonFiniteValue;

    // Sort every (row, col) slot tagged by origin; clashes land adjacent.
    const na = self.a.len();
    const keys = try allocator.alloc(u64, na + self.g.len());
    defer allocator.free(keys);
    for (self.a.rows, self.a.cols, 0..) |i, j, k| keys[k] = try self.slotKey(i, j, 0);
    for (self.g.rows, self.g.cols, 0..) |i, j, k| keys[na + k] = try self.slotKey(i, j, 1);
    std.mem.sortUnstable(u64, keys, {}, std.sort.asc(u64));
    var k: usize = 1;
    while (k < keys.len) : (k += 1) {
        const prev = keys[k - 1];
        const cur = keys[k];
        if (prev >> 1 != cur >> 1) continue;
        return if (prev & 1 == cur & 1) error.DuplicateEntry else error.OverlappingEntry;
    }
}

fn slotKey(self: *const Problem, i: u32, j: u32, origin: u1) ValidateError!u64 {
    if (i >= self.nf or j >= self.n) return error.IndexOutOfRange;
    return ((@as(u64, i) * self.n + j) << 1) | origin;
}

fn checkBounds(low: []const f64, upp: []const f64) ValidateError!void {
    for (low, upp) |l, u| {
        if (std.math.isNan(l) or std.math.isNan(u)) return error.NonFiniteValue;
        if (l > u) return error.InvertedBounds;
    }
}

// ---------------------------------------------------------------------------
// Validation procedure (TST-001). A 2x2 skeleton with a no-op callback.

const testing = std.testing;

fn noopEval(_: ?*anyopaque, _: Request) EvalError!void {}

const Skeleton = struct {
    const bounds_low = [2]f64{ -infinity, -infinity };
    const bounds_upp = [2]f64{ infinity, infinity };

    fn base() Problem {
        return .{
            .n = 2,
            .nf = 2,
            .obj_row = 0,
            .x_low = &bounds_low,
            .x_upp = &bounds_upp,
            .f_low = &bounds_low,
            .f_upp = &bounds_upp,
            .eval = noopEval,
        };
    }
};

test "validate: accepts a minimal well-formed problem" {
    var p = Skeleton.base();
    const rows = [_]u32{ 0, 1 };
    const cols = [_]u32{ 0, 1 };
    p.g = .{ .rows = &rows, .cols = &cols };
    try p.validate(testing.allocator);
}

test "validate: rejects inverted bounds" {
    var p = Skeleton.base();
    const low = [2]f64{ 1.0, 0.0 };
    const upp = [2]f64{ 0.0, 1.0 };
    p.x_low = &low;
    p.x_upp = &upp;
    try testing.expectError(error.InvertedBounds, p.validate(testing.allocator));
}

test "validate: rejects a slot declared in both A and G" {
    var p = Skeleton.base();
    const rows = [_]u32{1};
    const cols = [_]u32{0};
    const vals = [_]f64{2.0};
    p.a = .{ .rows = &rows, .cols = &cols, .vals = &vals };
    p.g = .{ .rows = &rows, .cols = &cols };
    try testing.expectError(error.OverlappingEntry, p.validate(testing.allocator));
}

test "validate: rejects duplicate G entries" {
    var p = Skeleton.base();
    const rows = [_]u32{ 1, 0, 1 };
    const cols = [_]u32{ 0, 1, 0 };
    p.g = .{ .rows = &rows, .cols = &cols };
    try testing.expectError(error.DuplicateEntry, p.validate(testing.allocator));
}

test "validate: rejects out-of-range indices" {
    var p = Skeleton.base();
    const rows = [_]u32{2};
    const cols = [_]u32{0};
    p.g = .{ .rows = &rows, .cols = &cols };
    try testing.expectError(error.IndexOutOfRange, p.validate(testing.allocator));
}

test "validate: rejects obj_row past nf and mismatched lengths" {
    var p = Skeleton.base();
    p.obj_row = 2;
    try testing.expectError(error.ObjRowOutOfRange, p.validate(testing.allocator));
    p.obj_row = null;
    p.nf = 3;
    try testing.expectError(error.LengthMismatch, p.validate(testing.allocator));
}

test "addLinear adds only the declared triplets" {
    var p = Skeleton.base();
    const rows = [_]u32{ 0, 0 };
    const cols = [_]u32{ 0, 1 };
    const vals = [_]f64{ 2.0, 3.0 };
    p.a = .{ .rows = &rows, .cols = &cols, .vals = &vals };
    var f = [2]f64{ 1.0, 1.0 };
    p.addLinear(&.{ 1.0, 2.0 }, &f);
    try testing.expectEqual(@as(f64, 9.0), f[0]);
    try testing.expectEqual(@as(f64, 1.0), f[1]);
}
