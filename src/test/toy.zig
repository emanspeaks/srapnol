//! snOptA user's-guide toy problem (`sntoya` in snopt7-examples):
//! minimize x2 s.t. x1^2 + 4 x2^2 <= 4, (x1 - 2)^2 + x2^2 <= 5, x1 >= 0.
//! Solution (0, -1), objective -1, with both rows and the bound active;
//! a degenerate vertex, so only primal values are asserted. Three layouts
//! share one callback: objective row in `G` as in the original, objective
//! row moved to `A`, and feasible-point-only (TST-012).

const srapnol = @import("../__root__.zig");
const support = @import("support.zig");
const Problem = srapnol.Problem;
const testing = support.testing;

pub const Toy = struct {
    pub const Mode = enum { obj_in_g, obj_in_a, feasible_only };
    mode: Mode,
    evals: usize = 0,

    pub const x0 = [2]f64{ 1.0, 1.0 };
    pub const x_star = [2]f64{ 0.0, -1.0 };
    pub const f_star: f64 = -1.0;
    /// Full F at `x_star`: objective, then both rows at their upper bounds.
    pub const big_f_star = [3]f64{ -1.0, 4.0, 5.0 };

    const inf = srapnol.infinity;
    const x_low = [2]f64{ 0.0, -inf };
    const x_upp = [2]f64{ inf, inf };
    const f_low = [3]f64{ -inf, -inf, -inf };
    const f_upp = [3]f64{ inf, 4.0, 5.0 };
    const g_rows_full = [_]u32{ 0, 0, 1, 1, 2, 2 };
    const g_cols_full = [_]u32{ 0, 1, 0, 1, 0, 1 };
    const g_rows_split = [_]u32{ 1, 1, 2, 2 };
    const g_cols_split = [_]u32{ 0, 1, 0, 1 };
    const a_rows = [_]u32{0};
    const a_cols = [_]u32{1};
    const a_vals = [_]f64{1.0};

    fn split(self: *const Toy) bool {
        return self.mode != .obj_in_g;
    }

    pub fn problem(self: *Toy) Problem {
        const a: Problem.Linear = if (self.split())
            .{ .rows = &a_rows, .cols = &a_cols, .vals = &a_vals }
        else
            .{};
        const g: Problem.Pattern = if (self.split())
            .{ .rows = &g_rows_split, .cols = &g_cols_split }
        else
            .{ .rows = &g_rows_full, .cols = &g_cols_full };
        return .{
            .n = 2,
            .nf = 3,
            .obj_row = if (self.mode == .feasible_only) null else 0,
            .x_low = &x_low,
            .x_upp = &x_upp,
            .f_low = &f_low,
            .f_upp = &f_upp,
            .a = a,
            .g = g,
            .eval = Problem.wrap(Toy, eval),
            .ctx = self,
            .name = "sntoya",
        };
    }

    fn eval(self: *Toy, req: Problem.Request) Problem.EvalError!void {
        self.evals += 1;
        const x1 = req.x[0];
        const x2 = req.x[1];
        if (req.f) |f| {
            f[0] = if (self.split()) 0.0 else x2;
            f[1] = x1 * x1 + 4.0 * x2 * x2;
            f[2] = (x1 - 2.0) * (x1 - 2.0) + x2 * x2;
        }
        if (req.g) |g| {
            var k: usize = 0;
            if (!self.split()) {
                g[0] = 0.0; // declared zero, as in the original example
                g[1] = 1.0;
                k = 2;
            }
            g[k] = 2.0 * x1;
            g[k + 1] = 8.0 * x2;
            g[k + 2] = 2.0 * (x1 - 2.0);
            g[k + 3] = 2.0 * x2;
        }
    }
};

const all_modes = [_]Toy.Mode{ .obj_in_g, .obj_in_a, .feasible_only };

test "toy: F at the documented optimum, in every layout" {
    for (all_modes) |mode| {
        var t = Toy{ .mode = mode };
        const p = t.problem();
        var f: [3]f64 = undefined;
        try support.evalFull(&p, &Toy.x_star, &f);
        try support.expectSliceAbs(&Toy.big_f_star, &f, 1e-15);
        try testing.expect(support.withinBox(&f, &Toy.f_low, &Toy.f_upp, 0.0));
        try testing.expect(support.withinBox(&Toy.x_star, &Toy.x_low, &Toy.x_upp, 0.0));
    }
}

test "toy: objective-in-G and objective-in-A agree on the full F" {
    var tg = Toy{ .mode = .obj_in_g };
    var ta = Toy{ .mode = .obj_in_a };
    const pg = tg.problem();
    const pa = ta.problem();
    const points = [_][2]f64{ Toy.x0, Toy.x_star, .{ 0.3, -0.7 }, .{ 2.5, 1.5 } };
    for (points) |x| {
        var fg: [3]f64 = undefined;
        var fa: [3]f64 = undefined;
        try support.evalFull(&pg, &x, &fg);
        try support.evalFull(&pa, &x, &fa);
        try support.expectSliceAbs(&fg, &fa, 1e-15);
    }
}

test "toy: analytic G matches central differences" {
    const points = [_][2]f64{ Toy.x0, Toy.x_star, .{ 0.3, -0.7 } };
    for (all_modes) |mode| {
        var t = Toy{ .mode = mode };
        const p = t.problem();
        for (points) |x| {
            const report = try support.checkJacobian(&p, &x, 1e-4);
            try report.expectOk(1e-8);
        }
    }
}

test "toy: every layout validates" {
    for (all_modes) |mode| {
        var t = Toy{ .mode = mode };
        const p = t.problem();
        try p.validate(testing.allocator);
    }
}

fn expectToyOptimum(state: *const srapnol.State, result: srapnol.Result) !void {
    try testing.expectEqual(srapnol.Exit.optimal, result.exit);
    try testing.expectApproxEqAbs(Toy.x_star[0], state.x[0], 1e-6);
    try testing.expectApproxEqRel(Toy.x_star[1], state.x[1], 1e-6);
    try testing.expectApproxEqRel(Toy.f_star, result.objective, 1e-8);
    try testing.expectApproxEqRel(Toy.f_star, state.f[0], 1e-8);
    try testing.expect(support.withinBox(state.f, &Toy.f_low, &Toy.f_upp, 1e-6));
    try testing.expect(support.withinBox(state.x, &Toy.x_low, &Toy.x_upp, 1e-9));
}

test "toy: solve with the objective row in G" {
    var t = Toy{ .mode = .obj_in_g };
    const p = t.problem();
    var solver = try srapnol.Solver.init(testing.allocator, &p, .{});
    defer solver.deinit();
    var state = try srapnol.State.init(testing.allocator, &p, &Toy.x0);
    defer state.deinit(testing.allocator);
    const result = try support.solveOrSkip(&solver, &state, .cold);
    try expectToyOptimum(&state, result);
}

test "toy: solve with the objective row in A" {
    var t = Toy{ .mode = .obj_in_a };
    const p = t.problem();
    var solver = try srapnol.Solver.init(testing.allocator, &p, .{});
    defer solver.deinit();
    var state = try srapnol.State.init(testing.allocator, &p, &Toy.x0);
    defer state.deinit(testing.allocator);
    const result = try support.solveOrSkip(&solver, &state, .cold);
    try expectToyOptimum(&state, result);
}

test "toy: feasible point only" {
    var t = Toy{ .mode = .feasible_only };
    const p = t.problem();
    var solver = try srapnol.Solver.init(testing.allocator, &p, .{});
    defer solver.deinit();
    var state = try srapnol.State.init(testing.allocator, &p, &Toy.x0);
    defer state.deinit(testing.allocator);
    const result = try support.solveOrSkip(&solver, &state, .cold);
    try testing.expectEqual(srapnol.Exit.feasible_point, result.exit);
    try testing.expectEqual(@as(f64, 0.0), result.objective);
    try testing.expect(support.withinBox(state.f, &Toy.f_low, &Toy.f_upp, 1e-6));
    try testing.expect(support.withinBox(state.x, &Toy.x_low, &Toy.x_upp, 1e-9));
}
