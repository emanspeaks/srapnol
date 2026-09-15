//! Test-rig helpers: tolerance asserts, the solve-or-skip shim, and an
//! independent central-difference Jacobian oracle (TST-2, TST-11). Kept
//! apart from the solver's own derivative checker so the two never share
//! a bug.

const std = @import("std");
const srapnol = @import("../__root__.zig");
const Problem = srapnol.Problem;

pub const testing = std.testing;
pub const allocator = std.testing.allocator;

/// Elementwise `std.testing.expectApproxEqRel`; std only has exact slice equality.
pub fn expectSliceRel(expected: []const f64, actual: []const f64, rel_tol: f64) !void {
    try testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |e, a| try testing.expectApproxEqRel(e, a, rel_tol);
}

pub fn expectSliceAbs(expected: []const f64, actual: []const f64, abs_tol: f64) !void {
    try testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |e, a| try testing.expectApproxEqAbs(e, a, abs_tol);
}

/// Runs `solve`, skipping the test while the solver is still a stub.
pub fn solveOrSkip(solver: *srapnol.Solver, state: *srapnol.State, start: srapnol.Start) !srapnol.Result {
    return solver.solve(state, start) catch |err| switch (err) {
        error.NotImplemented => error.SkipZigTest,
        else => err,
    };
}

/// Full `F(x) = f(x) + A x` into `out` (`out.len == nf`).
pub fn evalFull(problem: *const Problem, x: []const f64, out: []f64) !void {
    try problem.evaluate(x, out, null, .normal);
    problem.addLinear(x, out);
}

/// `low - tol <= v <= upp + tol` for every element.
pub fn withinBox(v: []const f64, low: []const f64, upp: []const f64, tol: f64) bool {
    for (v, low, upp) |x, lo, up| {
        if (x < lo - tol or x > up + tol) return false;
    }
    return true;
}

pub const JacobianReport = struct {
    /// Worst `|G_k - fd| / (1 + |fd|)` over declared entries.
    declared_err: f64 = 0,
    worst_declared: ?u32 = null,
    /// Worst `|fd| / (1 + colscale)` at slots outside the `G` pattern.
    undeclared_err: f64 = 0,
    worst_undeclared: ?[2]u32 = null,

    pub fn expectOk(self: JacobianReport, tol: f64) !void {
        if (self.declared_err <= tol and self.undeclared_err <= tol) return;
        std.debug.print(
            "jacobian: declared err {e} at entry {any}; undeclared err {e} at (row, col) {any}\n",
            .{ self.declared_err, self.worst_declared, self.undeclared_err, self.worst_undeclared },
        );
        return error.TestJacobianMismatch;
    }
};

const none = std.math.maxInt(u32);

const SortCtx = struct {
    rows: []const u32,
    cols: []const u32,
    nf: usize,

    fn key(c: SortCtx, k: u32) u64 {
        return @as(u64, c.cols[k]) * c.nf + c.rows[k];
    }

    fn lessThan(c: SortCtx, a: u32, b: u32) bool {
        return c.key(a) < c.key(b);
    }
};

/// Central differences on `f` with `h = rel_step * |x_j|` (or `rel_step`
/// when `x_j == 0`), compared against the callback's `G`. Slots outside
/// the pattern, `A` slots included, must difference to zero: `f` excludes
/// the linear terms.
pub fn checkJacobian(problem: *const Problem, x: []const f64, rel_step: f64) !JacobianReport {
    const n = problem.n;
    const nf = problem.nf;
    const ne = problem.g.len();
    const g = try allocator.alloc(f64, ne);
    defer allocator.free(g);
    const xp = try allocator.alloc(f64, n);
    defer allocator.free(xp);
    const fp = try allocator.alloc(f64, nf);
    defer allocator.free(fp);
    const fm = try allocator.alloc(f64, nf);
    defer allocator.free(fm);
    const decl = try allocator.alloc(u32, nf);
    defer allocator.free(decl);
    const order = try allocator.alloc(u32, ne);
    defer allocator.free(order);

    for (order, 0..) |*o, k| o.* = @intCast(k);
    const ctx = SortCtx{ .rows = problem.g.rows, .cols = problem.g.cols, .nf = nf };
    std.mem.sortUnstable(u32, order, ctx, SortCtx.lessThan);

    try problem.evaluate(x, null, g, .normal);
    @memcpy(xp, x);

    var report = JacobianReport{};
    var p: usize = 0;
    for (0..n) |j| {
        const xj = x[j];
        const h = if (xj != 0) rel_step * @abs(xj) else rel_step;
        xp[j] = xj + h;
        try problem.evaluate(xp, fp, null, .normal);
        xp[j] = xj - h;
        try problem.evaluate(xp, fm, null, .normal);
        xp[j] = xj;

        @memset(decl, none);
        var colscale: f64 = 0;
        while (p < ne and problem.g.cols[order[p]] == j) : (p += 1) {
            const k = order[p];
            decl[problem.g.rows[k]] = k;
            colscale = @max(colscale, @abs(g[k]));
        }
        for (0..nf) |i| {
            const fd = (fp[i] - fm[i]) / (2.0 * h);
            if (decl[i] != none) {
                const err = @abs(g[decl[i]] - fd) / (1.0 + @abs(fd));
                if (err > report.declared_err) {
                    report.declared_err = err;
                    report.worst_declared = decl[i];
                }
            } else {
                const err = @abs(fd) / (1.0 + colscale);
                if (err > report.undeclared_err) {
                    report.undeclared_err = err;
                    report.worst_undeclared = .{ @intCast(i), @intCast(j) };
                }
            }
        }
    }
    return report;
}

// ---------------------------------------------------------------------------
// The oracle's own tests: `f = [x0 x1, x0^2]`, `F_1 = f_1 + 3 x1`, with
// one deliberate defect at a time.

const Quad = struct {
    const Defect = enum { none, wrong_value, masked_entry, linear_in_f };
    defect: Defect,

    const low = [2]f64{ -srapnol.infinity, -srapnol.infinity };
    const upp = [2]f64{ srapnol.infinity, srapnol.infinity };
    const g_rows_full = [_]u32{ 0, 0, 1 };
    const g_cols_full = [_]u32{ 0, 1, 0 };
    const g_rows_masked = [_]u32{ 0, 1 };
    const g_cols_masked = [_]u32{ 0, 0 };
    const a_rows = [_]u32{1};
    const a_cols = [_]u32{1};
    const a_vals = [_]f64{3.0};

    fn problem(self: *Quad) Problem {
        const g: Problem.Pattern = if (self.defect == .masked_entry)
            .{ .rows = &g_rows_masked, .cols = &g_cols_masked }
        else
            .{ .rows = &g_rows_full, .cols = &g_cols_full };
        return .{
            .n = 2,
            .nf = 2,
            .obj_row = 0,
            .x_low = &low,
            .x_upp = &upp,
            .f_low = &low,
            .f_upp = &upp,
            .a = .{ .rows = &a_rows, .cols = &a_cols, .vals = &a_vals },
            .g = g,
            .eval = Problem.wrap(Quad, eval),
            .ctx = self,
        };
    }

    fn eval(self: *Quad, req: Problem.Request) Problem.EvalError!void {
        const x0 = req.x[0];
        const x1 = req.x[1];
        if (req.f) |f| {
            f[0] = x0 * x1;
            f[1] = x0 * x0 + if (self.defect == .linear_in_f) 3.0 * x1 else 0.0;
        }
        if (req.g) |g| {
            g[0] = x1;
            if (self.defect == .masked_entry) {
                g[1] = 2.0 * x0;
            } else {
                g[1] = x0;
                g[2] = if (self.defect == .wrong_value) 3.0 * x0 else 2.0 * x0;
            }
        }
    }
};

const quad_point = [2]f64{ 1.5, -0.75 };

test "jacobian oracle: passes a correct G" {
    var q = Quad{ .defect = .none };
    const p = q.problem();
    try p.validate(allocator);
    const r = try checkJacobian(&p, &quad_point, 1e-4);
    try r.expectOk(1e-8);
}

test "jacobian oracle: flags a wrong derivative value" {
    var q = Quad{ .defect = .wrong_value };
    const p = q.problem();
    const r = try checkJacobian(&p, &quad_point, 1e-4);
    try testing.expect(r.declared_err > 0.1);
    try testing.expectEqual(@as(?u32, 2), r.worst_declared);
}

test "jacobian oracle: flags a nonzero outside the declared pattern" {
    var q = Quad{ .defect = .masked_entry };
    const p = q.problem();
    const r = try checkJacobian(&p, &quad_point, 1e-4);
    try testing.expect(r.declared_err < 1e-8);
    try testing.expect(r.undeclared_err > 0.1);
    try testing.expectEqual([2]u32{ 0, 1 }, r.worst_undeclared.?);
}

test "jacobian oracle: flags linear terms leaking into f" {
    var q = Quad{ .defect = .linear_in_f };
    const p = q.problem();
    const r = try checkJacobian(&p, &quad_point, 1e-4);
    try testing.expect(r.undeclared_err > 0.1);
    try testing.expectEqual([2]u32{ 1, 1 }, r.worst_undeclared.?);
}

test "evalFull adds the linear part" {
    var q = Quad{ .defect = .none };
    const p = q.problem();
    var f: [2]f64 = undefined;
    try evalFull(&p, &quad_point, &f);
    try testing.expectApproxEqRel(1.5 * -0.75, f[0], 1e-15);
    try testing.expectApproxEqRel(1.5 * 1.5 + 3.0 * -0.75, f[1], 1e-15);
}
