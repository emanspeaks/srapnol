//! Hock-Schittkowski 15 (snopt7-examples `hs15.f`, re-posed for the A
//! interface): the Rosenbrock objective with `x1 x2 >= 1`, `x1 + x2^2 >= 0`
//! and `x1 <= 0.5`. The start (-2, 1) violates the first row; the optimum
//! (0.5, 2) has that row and the bound active, with objective 306.5.
//! Row 2 keeps its linear term in `A` (TST-014).

const srapnol = @import("../__root__.zig");
const support = @import("support.zig");
const Problem = srapnol.Problem;
const testing = support.testing;

pub const Hs15 = struct {
    evals: usize = 0,

    pub const x0 = [2]f64{ -2.0, 1.0 };
    pub const x_star = [2]f64{ 0.5, 2.0 };
    pub const f_star: f64 = 306.5;
    /// Multiplier of row 1 (`x1 x2 >= 1`, at its lower bound).
    pub const pi_star: f64 = 700.0;
    /// Multiplier of the bound `x1 <= 0.5`.
    pub const mu_star: f64 = -1751.0;

    const inf = srapnol.infinity;
    const x_low = [2]f64{ -inf, -inf };
    const x_upp = [2]f64{ 0.5, inf };
    const f_low = [3]f64{ -inf, 1.0, 0.0 };
    const f_upp = [3]f64{ inf, inf, inf };
    const g_rows = [_]u32{ 0, 0, 1, 1, 2 };
    const g_cols = [_]u32{ 0, 1, 0, 1, 1 };
    const a_rows = [_]u32{2};
    const a_cols = [_]u32{0};
    const a_vals = [_]f64{1.0};

    pub fn problem(self: *Hs15) Problem {
        return .{
            .n = 2,
            .nf = 3,
            .obj_row = 0,
            .x_low = &x_low,
            .x_upp = &x_upp,
            .f_low = &f_low,
            .f_upp = &f_upp,
            .a = .{ .rows = &a_rows, .cols = &a_cols, .vals = &a_vals },
            .g = .{ .rows = &g_rows, .cols = &g_cols },
            .eval = Problem.wrap(Hs15, eval),
            .ctx = self,
            .name = "hs15",
        };
    }

    pub fn objective(x1: f64, x2: f64) f64 {
        const r = x2 - x1 * x1;
        const q = 1.0 - x1;
        return 100.0 * r * r + q * q;
    }

    pub fn gradient(x1: f64, x2: f64) [2]f64 {
        const r = x2 - x1 * x1;
        return .{ -400.0 * x1 * r - 2.0 * (1.0 - x1), 200.0 * r };
    }

    fn eval(self: *Hs15, req: Problem.Request) Problem.EvalError!void {
        self.evals += 1;
        const x1 = req.x[0];
        const x2 = req.x[1];
        if (req.f) |f| {
            f[0] = objective(x1, x2);
            f[1] = x1 * x2;
            f[2] = x2 * x2; // + x1 via A
        }
        if (req.g) |g| {
            const grad = gradient(x1, x2);
            g[0] = grad[0];
            g[1] = grad[1];
            g[2] = x2;
            g[3] = x1;
            g[4] = 2.0 * x2;
        }
    }
};

test "hs15: documented optimum: objective, active set, multipliers" {
    var h = Hs15{};
    const p = h.problem();
    var f: [3]f64 = undefined;
    try support.evalFull(&p, &Hs15.x_star, &f);
    try testing.expectApproxEqRel(Hs15.f_star, f[0], 1e-14);
    try testing.expectApproxEqRel(1.0, f[1], 1e-15); // row 1 at its lower bound
    try testing.expect(f[2] > 0.0); // row 2 slack
    try testing.expectEqual(Hs15.x_upp[0], Hs15.x_star[0]); // bound active

    // KKT: grad f = pi * grad F1 + mu * e1, pi >= 0 (lower bound), mu <= 0 (upper bound).
    const grad = Hs15.gradient(Hs15.x_star[0], Hs15.x_star[1]);
    const pi = grad[1] / Hs15.x_star[0]; // second component has no bound term
    const mu = grad[0] - pi * Hs15.x_star[1];
    try testing.expectApproxEqRel(Hs15.pi_star, pi, 1e-14);
    try testing.expectApproxEqRel(Hs15.mu_star, mu, 1e-14);
    try testing.expect(pi > 0 and mu < 0);
}

test "hs15: start violates row 1" {
    var h = Hs15{};
    const p = h.problem();
    var f: [3]f64 = undefined;
    try support.evalFull(&p, &Hs15.x0, &f);
    try testing.expect(f[1] < Hs15.f_low[1]);
}

test "hs15: analytic G matches central differences" {
    var h = Hs15{};
    const p = h.problem();
    const points = [_][2]f64{ Hs15.x0, Hs15.x_star, .{ 0.3, 1.7 } };
    for (points) |x| {
        const report = try support.checkJacobian(&p, &x, 1e-4);
        try report.expectOk(1e-6);
    }
}

test "hs15: problem definition validates" {
    var h = Hs15{};
    const p = h.problem();
    try p.validate(testing.allocator);
}

test "hs15: solve from the infeasible start" {
    var h = Hs15{};
    const p = h.problem();
    var solver = try srapnol.Solver.init(testing.allocator, &p, .{});
    defer solver.deinit();
    var state = try srapnol.State.init(testing.allocator, &p, &Hs15.x0);
    defer state.deinit(testing.allocator);

    const result = try support.solveOrSkip(&solver, &state, .cold);
    try testing.expectEqual(srapnol.Exit.optimal, result.exit);
    try support.expectSliceRel(&Hs15.x_star, state.x, 1e-6);
    try testing.expectApproxEqRel(Hs15.f_star, result.objective, 1e-8);
    try testing.expectEqual(srapnol.VarState.nonbasic_lower, state.f_state[1]);
    try testing.expectEqual(srapnol.VarState.nonbasic_upper, state.x_state[0]);
    try testing.expectApproxEqRel(Hs15.pi_star, state.f_mul[1], 1e-4);
    try testing.expectApproxEqRel(Hs15.mu_star, state.x_mul[0], 1e-4);
}
