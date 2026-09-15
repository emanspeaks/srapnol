//! Hock-Schittkowski 76 (snopt7-examples `hs76.f`): a convex QP in four
//! variables with three linear rows, all in `A`, and the quadratic
//! objective in `G`. Exact solution (3, 23, 0, 6)/11, objective -103/22,
//! with row 1 at its upper bound and `x3` at its lower bound (TST-8).

const srapnol = @import("../__root__.zig");
const support = @import("support.zig");
const Problem = srapnol.Problem;
const testing = support.testing;

pub const Hs76 = struct {
    evals: usize = 0,

    pub const x0: [4]f64 = @splat(0.5);
    pub const x_star = [4]f64{ 3.0 / 11.0, 23.0 / 11.0, 0.0, 6.0 / 11.0 };
    pub const f_star: f64 = -103.0 / 22.0;
    /// Multiplier of row 1 (at its upper bound).
    pub const pi_star: f64 = -5.0 / 11.0;
    /// Multiplier of the bound `x3 >= 0`.
    pub const mu_star: f64 = 19.0 / 11.0;

    const inf = srapnol.infinity;
    const x_low: [4]f64 = @splat(0.0);
    const x_upp: [4]f64 = @splat(inf);
    const f_low = [4]f64{ -inf, -inf, -inf, 1.5 };
    const f_upp = [4]f64{ inf, 5.0, 4.0, inf };
    const g_rows = [_]u32{ 0, 0, 0, 0 };
    const g_cols = [_]u32{ 0, 1, 2, 3 };
    const a_rows = [_]u32{ 1, 1, 1, 1, 2, 2, 2, 2, 3, 3 };
    const a_cols = [_]u32{ 0, 1, 2, 3, 0, 1, 2, 3, 1, 2 };
    const a_vals = [_]f64{ 1.0, 2.0, 1.0, 1.0, 3.0, 1.0, 2.0, -1.0, 1.0, 4.0 };

    pub fn problem(self: *Hs76) Problem {
        return .{
            .n = 4,
            .nf = 4,
            .obj_row = 0,
            .x_low = &x_low,
            .x_upp = &x_upp,
            .f_low = &f_low,
            .f_upp = &f_upp,
            .a = .{ .rows = &a_rows, .cols = &a_cols, .vals = &a_vals },
            .g = .{ .rows = &g_rows, .cols = &g_cols },
            .eval = Problem.wrap(Hs76, eval),
            .ctx = self,
            .name = "hs76",
        };
    }

    pub fn objective(x: []const f64) f64 {
        return x[0] * x[0] + 0.5 * x[1] * x[1] + x[2] * x[2] + 0.5 * x[3] * x[3] -
            x[0] * x[2] + x[2] * x[3] - x[0] - 3.0 * x[1] + x[2] - x[3];
    }

    pub fn gradient(x: []const f64) [4]f64 {
        return .{
            2.0 * x[0] - x[2] - 1.0,
            x[1] - 3.0,
            2.0 * x[2] - x[0] + x[3] + 1.0,
            x[3] + x[2] - 1.0,
        };
    }

    fn eval(self: *Hs76, req: Problem.Request) Problem.EvalError!void {
        self.evals += 1;
        if (req.f) |f| {
            f[0] = objective(req.x);
            f[1] = 0.0; // rows 1..3 are entirely linear
            f[2] = 0.0;
            f[3] = 0.0;
        }
        if (req.g) |g| {
            const grad = gradient(req.x);
            @memcpy(g[0..4], &grad);
        }
    }
};

test "hs76: documented optimum: objective, active set, multipliers" {
    var h = Hs76{};
    const p = h.problem();
    var f: [4]f64 = undefined;
    try support.evalFull(&p, &Hs76.x_star, &f);
    try testing.expectApproxEqRel(Hs76.f_star, f[0], 1e-14);
    try testing.expectApproxEqRel(5.0, f[1], 1e-14); // row 1 at its upper bound
    try testing.expect(f[2] < Hs76.f_upp[2]); // rows 2 and 3 slack
    try testing.expect(f[3] > Hs76.f_low[3]);
    try testing.expectEqual(@as(f64, 0.0), Hs76.x_star[2]); // x3 at its lower bound

    // KKT: grad f = pi * (1, 2, 1, 1) + mu * e3, pi <= 0 (upper bound), mu >= 0 (lower bound).
    const grad = Hs76.gradient(&Hs76.x_star);
    const pi = grad[0];
    try testing.expectApproxEqRel(Hs76.pi_star, pi, 1e-14);
    try testing.expectApproxEqRel(2.0 * pi, grad[1], 1e-14);
    try testing.expectApproxEqRel(pi, grad[3], 1e-14);
    const mu = grad[2] - pi;
    try testing.expectApproxEqRel(Hs76.mu_star, mu, 1e-14);
    try testing.expect(pi < 0 and mu > 0);
}

test "hs76: analytic G matches central differences" {
    var h = Hs76{};
    const p = h.problem();
    const points = [_][4]f64{ Hs76.x0, Hs76.x_star, .{ 1.0, -2.0, 0.5, 3.0 } };
    for (points) |x| {
        const report = try support.checkJacobian(&p, &x, 1e-4);
        try report.expectOk(1e-8);
    }
}

test "hs76: problem definition validates" {
    var h = Hs76{};
    const p = h.problem();
    try p.validate(testing.allocator);
    try testing.expectEqual(@as(usize, 4), p.g.len());
    try testing.expectEqual(@as(usize, 10), p.a.len());
}

test "hs76: solve the QP" {
    var h = Hs76{};
    const p = h.problem();
    var solver = try srapnol.Solver.init(testing.allocator, &p, .{});
    defer solver.deinit();
    var state = try srapnol.State.init(testing.allocator, &p, &Hs76.x0);
    defer state.deinit(testing.allocator);

    const result = try support.solveOrSkip(&solver, &state, .cold);
    try testing.expectEqual(srapnol.Exit.optimal, result.exit);
    try support.expectSliceAbs(&Hs76.x_star, state.x, 1e-6);
    try testing.expectApproxEqRel(Hs76.f_star, result.objective, 1e-8);
    try testing.expectEqual(srapnol.VarState.nonbasic_upper, state.f_state[1]);
    try testing.expectEqual(srapnol.VarState.nonbasic_lower, state.x_state[2]);
    try testing.expectApproxEqRel(Hs76.pi_star, state.f_mul[1], 1e-4);
    try testing.expectApproxEqRel(Hs76.mu_star, state.x_mul[2], 1e-4);
}
