//! Three-bar truss sizing problem from `example.md`: the primary
//! acceptance case (TST-008 to TST-011). Two areas, a linear weight objective
//! held in `A`, and three two-sided nonlinear stress rows in `G`.

const std = @import("std");
const srapnol = @import("../__root__.zig");
const support = @import("support.zig");
const Problem = srapnol.Problem;
const testing = support.testing;

const sqrt2 = std.math.sqrt2;

pub const Truss = struct {
    rho: f64,
    h: f64,
    sigma_allow: f64,
    p1: f64,
    p2: f64,
    /// Bound/coefficient storage the `Problem` slices point into.
    x_low: [2]f64,
    x_upp: [2]f64,
    f_low: [4]f64,
    f_upp: [4]f64,
    a_vals: [2]f64,
    evals: usize = 0,

    /// Generic feasible start from `example.md`.
    pub const x0 = [2]f64{ 5.0e-4, 5.0e-4 };

    const g_rows = [_]u32{ 1, 1, 2, 2, 3, 3 };
    const g_cols = [_]u32{ 0, 1, 0, 1, 0, 1 };
    const a_rows = [_]u32{ 0, 0 };
    const a_cols = [_]u32{ 0, 1 };

    pub fn init() Truss {
        const rho = 7800.0;
        const h = 1.0;
        const s = 2.0e8;
        return .{
            .rho = rho,
            .h = h,
            .sigma_allow = s,
            .p1 = 20_000.0,
            .p2 = -20_000.0,
            .x_low = .{ 1.0e-6, 1.0e-6 },
            .x_upp = .{ 1.0e-2, 1.0e-2 },
            .f_low = .{ -srapnol.infinity, -s, -s, -s },
            .f_upp = .{ srapnol.infinity, s, s, s },
            .a_vals = .{ 2.0 * sqrt2 * rho * h, rho * h },
        };
    }

    pub fn problem(self: *Truss) Problem {
        return .{
            .n = 2,
            .nf = 4,
            .obj_row = 0,
            .x_low = &self.x_low,
            .x_upp = &self.x_upp,
            .f_low = &self.f_low,
            .f_upp = &self.f_upp,
            .a = .{ .rows = &a_rows, .cols = &a_cols, .vals = &self.a_vals },
            .g = .{ .rows = &g_rows, .cols = &g_cols },
            .eval = Problem.wrap(Truss, eval),
            .ctx = self,
            .name = "three-bar truss",
        };
    }

    /// Bar stresses; `D = sqrt2 x1 + 2 x2`.
    pub fn stresses(self: *const Truss, x1: f64, x2: f64) [3]f64 {
        const d = sqrt2 * x1 + 2.0 * x2;
        const t = self.p1 / (sqrt2 * x1);
        const u = self.p2 / d;
        return .{ t + u, 2.0 * u, -t + u };
    }

    /// `d sigma_i / d x_j`, rows `i` in 0..3, cols `j` in 0..2.
    pub fn stressJacobian(self: *const Truss, x1: f64, x2: f64) [3][2]f64 {
        const d = sqrt2 * x1 + 2.0 * x2;
        const d2 = d * d;
        const dt = -self.p1 / (sqrt2 * x1 * x1);
        const du1 = -sqrt2 * self.p2 / d2;
        const du2 = -2.0 * self.p2 / d2;
        return .{
            .{ dt + du1, du2 },
            .{ 2.0 * du1, 2.0 * du2 },
            .{ -dt + du1, du2 },
        };
    }

    pub fn weight(self: *const Truss, x1: f64, x2: f64) f64 {
        return self.rho * self.h * (2.0 * sqrt2 * x1 + x2);
    }

    fn eval(self: *Truss, req: Problem.Request) Problem.EvalError!void {
        self.evals += 1;
        const x1 = req.x[0];
        const x2 = req.x[1];
        if (req.f) |f| {
            const s = self.stresses(x1, x2);
            f[0] = 0.0; // objective row lives entirely in A
            f[1] = s[0];
            f[2] = s[1];
            f[3] = s[2];
        }
        if (req.g) |g| {
            const j = self.stressJacobian(x1, x2);
            g[0] = j[0][0];
            g[1] = j[0][1];
            g[2] = j[1][0];
            g[3] = j[1][1];
            g[4] = j[2][0];
            g[5] = j[2][1];
        }
    }

    pub const Optimum = struct {
        x: [2]f64,
        f: f64,
        sigma: [3]f64,
        /// Multiplier of the binding row `sigma3 >= -sigma_allow`.
        lambda: f64,
    };

    /// Closed form for `p1 > 0 > p2`, where only `sigma3` binds.
    /// Stationarity forces `D = r x1` with `r = sqrt(-6 p2 / p1)`, hence
    /// `x2 = (r - sqrt2) x1 / 2`; `sigma3 = -sigma_allow` then fixes `x1`.
    pub fn optimum(self: *const Truss) Optimum {
        std.debug.assert(self.p1 > 0 and self.p2 < 0);
        const r = @sqrt(-6.0 * self.p2 / self.p1);
        const x1 = (self.p1 / sqrt2 - self.p2 / r) / self.sigma_allow;
        const x2 = (r - sqrt2) * x1 / 2.0;
        const jac = self.stressJacobian(x1, x2);
        return .{
            .x = .{ x1, x2 },
            .f = self.weight(x1, x2),
            .sigma = self.stresses(x1, x2),
            .lambda = self.rho * self.h / jac[2][1],
        };
    }
};

test "truss: sigma1 + sigma3 == sigma2 at every design point" {
    const t = Truss.init();
    var i: usize = 0;
    while (i <= 4) : (i += 1) {
        var j: usize = 0;
        while (j <= 4) : (j += 1) {
            const x1 = t.x_low[0] * std.math.pow(f64, 10.0, @floatFromInt(i));
            const x2 = t.x_low[1] * std.math.pow(f64, 10.0, @floatFromInt(j));
            const s = t.stresses(x1, x2);
            try testing.expectApproxEqRel(s[1], s[0] + s[2], 1e-10);
        }
    }
}

test "truss: problem definition validates" {
    var t = Truss.init();
    const p = t.problem();
    try p.validate(testing.allocator);
    try testing.expectEqual(@as(usize, 6), p.g.len());
    try testing.expectEqual(@as(usize, 2), p.a.len());
}

test "truss: analytic G matches central differences" {
    var t = Truss.init();
    const p = t.problem();
    const opt = t.optimum();
    const points = [_][2]f64{ Truss.x0, opt.x, .{ 1.0e-5, 1.0e-3 }, .{ 5.0e-3, 2.0e-6 } };
    for (points) |x| {
        const report = try support.checkJacobian(&p, &x, 1e-4);
        try report.expectOk(1e-6);
    }
}

test "truss: documented optimum is the KKT point of the closed form" {
    var t = Truss.init();
    const p = t.problem();
    const opt = t.optimum();

    // example.md, section 5 (five significant figures).
    try testing.expectApproxEqRel(1.1154e-4, opt.x[0], 1e-4);
    try testing.expectApproxEqRel(5.7735e-5, opt.x[1], 1e-4);
    try testing.expectApproxEqRel(2.911, opt.f, 1e-3);
    try testing.expectApproxEqRel(-2.0e8, opt.sigma[2], 1e-12);
    try testing.expectApproxEqRel(5.36e7, opt.sigma[0], 1e-2);
    try testing.expectApproxEqRel(-1.464e8, opt.sigma[1], 1e-3);
    try testing.expectApproxEqRel(opt.sigma[1], opt.sigma[0] + opt.sigma[2], 1e-10);

    // Closed forms for p1 = -p2: x1 = (p1/s)(1/sqrt2 + 1/sqrt6),
    // x2 = (p1/s)/sqrt3, f = rho h (2 + sqrt3) p1/s.
    const scale = t.p1 / t.sigma_allow;
    try testing.expectApproxEqRel(scale * (1.0 / sqrt2 + 1.0 / @sqrt(6.0)), opt.x[0], 1e-14);
    try testing.expectApproxEqRel(scale / @sqrt(3.0), opt.x[1], 1e-14);
    try testing.expectApproxEqRel(t.rho * t.h * (2.0 + @sqrt(3.0)) * scale, opt.f, 1e-14);

    // Only sigma3 binds; the other rows and every bound are slack.
    try testing.expect(opt.sigma[0] < t.sigma_allow and opt.sigma[0] > -t.sigma_allow);
    try testing.expect(opt.sigma[1] < t.sigma_allow and opt.sigma[1] > -t.sigma_allow);
    try testing.expect(opt.x[0] > t.x_low[0] and opt.x[0] < t.x_upp[0]);
    try testing.expect(opt.x[1] > t.x_low[1] and opt.x[1] < t.x_upp[1]);

    // Stationarity: grad f = lambda grad sigma3 with lambda > 0.
    const jac = t.stressJacobian(opt.x[0], opt.x[1]);
    try testing.expect(opt.lambda > 0);
    try testing.expectApproxEqRel(t.a_vals[0], opt.lambda * jac[2][0], 1e-12);
    try testing.expectApproxEqRel(t.a_vals[1], opt.lambda * jac[2][1], 1e-12);

    // Full F through the A/G split reproduces the benchmark numbers.
    var f: [4]f64 = undefined;
    try support.evalFull(&p, &opt.x, &f);
    try testing.expectApproxEqRel(opt.f, f[0], 1e-14);
    try support.expectSliceRel(&opt.sigma, f[1..], 1e-14);
}

test "truss: solve from the generic start reaches the benchmark optimum" {
    var t = Truss.init();
    const p = t.problem();
    var solver = try srapnol.Solver.init(testing.allocator, &p, .{});
    defer solver.deinit();
    var state = try srapnol.State.init(testing.allocator, &p, &Truss.x0);
    defer state.deinit(testing.allocator);

    const result = try support.solveOrSkip(&solver, &state, .cold);
    const opt = t.optimum();

    try testing.expectEqual(srapnol.Exit.optimal, result.exit);
    try support.expectSliceRel(&opt.x, state.x, 1e-5);
    try testing.expectApproxEqRel(opt.f, result.objective, 1e-6);
    try testing.expectApproxEqRel(opt.f, state.f[0], 1e-6);
    try testing.expectApproxEqRel(-t.sigma_allow, state.f[3], 1e-6);
    try testing.expect(support.withinBox(state.f, &t.f_low, &t.f_upp, 1e-6 * t.sigma_allow));
    try testing.expect(support.withinBox(state.x, &t.x_low, &t.x_upp, 0.0));
    try testing.expectEqual(srapnol.VarState.nonbasic_lower, state.f_state[3]);
    try testing.expectApproxEqRel(opt.lambda, state.f_mul[3], 1e-3);
    try testing.expect(result.major_iterations > 0);
    try testing.expect(t.evals > 0);
}
