//! Hock-Schittkowski 47 as laid out in snopt7-examples `hs47a.f`: five
//! variables, three equality rows mixing linear (`A`) and nonlinear (`G`)
//! terms, objective in the last row. Solution: all ones, objective 0.
//! The objective is quartic along some feasible directions, so `x` is
//! only pinned to 1e-2 while the objective and rows are tight (TST-013).

const std = @import("std");
const srapnol = @import("../__root__.zig");
const support = @import("support.zig");
const Problem = srapnol.Problem;
const testing = support.testing;

const sqrt2 = std.math.sqrt2;

pub const Hs47 = struct {
    evals: usize = 0,

    /// Feasible start from the reference example.
    pub const x0 = [5]f64{ 2.0, sqrt2, -1.0, 2.0 - sqrt2, 0.5 };
    pub const x_star: [5]f64 = @splat(1.0);
    pub const f_star: f64 = 0.0;
    pub const obj_row: u32 = 3;
    /// Equality targets of rows 0..3.
    pub const rhs = [3]f64{ 3.0, 1.0, 1.0 };

    const inf = srapnol.infinity;
    const x_low: [5]f64 = @splat(-inf);
    const x_upp: [5]f64 = @splat(inf);
    const f_low = [4]f64{ 3.0, 1.0, 1.0, -inf };
    const f_upp = [4]f64{ 3.0, 1.0, 1.0, inf };
    // Objective gradient first, then rows 0, 1, 2; same order as hs47a.f.
    const g_rows = [_]u32{ 3, 3, 3, 3, 3, 0, 0, 1, 2, 2 };
    const g_cols = [_]u32{ 0, 1, 2, 3, 4, 1, 2, 2, 0, 4 };
    const a_rows = [_]u32{ 0, 1, 1 };
    const a_cols = [_]u32{ 0, 1, 3 };
    const a_vals = [_]f64{ 1.0, 1.0, 1.0 };

    pub fn problem(self: *Hs47) Problem {
        return .{
            .n = 5,
            .nf = 4,
            .obj_row = obj_row,
            .x_low = &x_low,
            .x_upp = &x_upp,
            .f_low = &f_low,
            .f_upp = &f_upp,
            .a = .{ .rows = &a_rows, .cols = &a_cols, .vals = &a_vals },
            .g = .{ .rows = &g_rows, .cols = &g_cols },
            .eval = Problem.wrap(Hs47, eval),
            .ctx = self,
            .name = "hs47",
        };
    }

    pub fn objective(x: []const f64) f64 {
        const d1 = x[0] - x[1];
        const d2 = x[1] - x[2];
        const d3 = x[2] - x[3];
        const d4 = x[3] - x[4];
        return d1 * d1 + d2 * d2 * d2 + d3 * d3 * d3 * d3 + d4 * d4 * d4 * d4;
    }

    fn eval(self: *Hs47, req: Problem.Request) Problem.EvalError!void {
        self.evals += 1;
        const x = req.x;
        if (req.f) |f| {
            f[0] = x[1] * x[1] + x[2] * x[2] * x[2]; // + x1 via A
            f[1] = -x[2] * x[2]; // + x2 + x4 via A
            f[2] = x[0] * x[4];
            f[3] = objective(x);
        }
        if (req.g) |g| {
            const d1 = x[0] - x[1];
            const d2 = x[1] - x[2];
            const d3 = x[2] - x[3];
            const d4 = x[3] - x[4];
            g[0] = 2.0 * d1;
            g[1] = 3.0 * d2 * d2 - 2.0 * d1;
            g[2] = 4.0 * d3 * d3 * d3 - 3.0 * d2 * d2;
            g[3] = 4.0 * d4 * d4 * d4 - 4.0 * d3 * d3 * d3;
            g[4] = -4.0 * d4 * d4 * d4;
            g[5] = 2.0 * x[1];
            g[6] = 3.0 * x[2] * x[2];
            g[7] = -2.0 * x[2];
            g[8] = x[4];
            g[9] = x[0];
        }
    }
};

test "hs47: start and optimum satisfy the equality rows" {
    var h = Hs47{};
    const p = h.problem();
    var f: [4]f64 = undefined;
    try support.evalFull(&p, &Hs47.x0, &f);
    try support.expectSliceAbs(&Hs47.rhs, f[0..3], 1e-12);
    try support.evalFull(&p, &Hs47.x_star, &f);
    try support.expectSliceAbs(&Hs47.rhs, f[0..3], 1e-15);
    try testing.expectApproxEqAbs(Hs47.f_star, f[Hs47.obj_row], 1e-15);
}

test "hs47: analytic G matches central differences" {
    var h = Hs47{};
    const p = h.problem();
    const points = [_][5]f64{ Hs47.x0, Hs47.x_star, .{ 1.5, 0.5, -0.5, 1.2, 0.8 } };
    for (points) |x| {
        const report = try support.checkJacobian(&p, &x, 1e-4);
        try report.expectOk(1e-6);
    }
}

test "hs47: problem definition validates" {
    var h = Hs47{};
    const p = h.problem();
    try p.validate(testing.allocator);
    try testing.expectEqual(@as(usize, 10), p.g.len());
    try testing.expectEqual(@as(usize, 3), p.a.len());
}

test "hs47: solve from the feasible start reaches all ones" {
    var h = Hs47{};
    const p = h.problem();
    var solver = try srapnol.Solver.init(testing.allocator, &p, .{});
    defer solver.deinit();
    var state = try srapnol.State.init(testing.allocator, &p, &Hs47.x0);
    defer state.deinit(testing.allocator);

    const result = try support.solveOrSkip(&solver, &state, .cold);
    try testing.expectEqual(srapnol.Exit.optimal, result.exit);
    try testing.expectApproxEqAbs(Hs47.f_star, result.objective, 1e-6);
    try support.expectSliceAbs(&Hs47.x_star, state.x, 1e-2);
    try support.expectSliceAbs(&Hs47.rhs, state.f[0..3], 1e-6);
}
