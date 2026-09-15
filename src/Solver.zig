//! SQP driver: owns the workspace and runs major/minor iterations.
//! Currently a stub; `solve` returns `error.NotImplemented` until the
//! roadmap phases land, and the test rig skips on that error.

const std = @import("std");
const Problem = @import("Problem.zig");
const Options = @import("Options.zig");
const Solver = @This();

/// snOptA `Start`: cold ignores states, basis uses states, warm uses all of `State`.
pub const Start = enum { cold, basis, warm };

/// Per-variable and per-row state; values match snOptA's `xstate`/`Fstate` (SRS-073).
pub const VarState = enum(u8) {
    nonbasic_lower = 0,
    nonbasic_upper = 1,
    superbasic = 2,
    basic = 3,
};

/// Primal/dual iterate: warm-start input and solution output (SRS-061).
pub const State = struct {
    x: []f64,
    x_state: []VarState,
    /// Bound multipliers: `>= 0` at a lower bound, `<= 0` at an upper bound.
    x_mul: []f64,
    /// Full `F(x) = f(x) + A x` on exit.
    f: []f64,
    f_state: []VarState,
    /// Row multipliers with `grad F_obj = sum_i f_mul[i] grad F_i + x_mul`.
    f_mul: []f64,

    pub const InitError = error{ OutOfMemory, LengthMismatch };

    /// Caller-owned (SRS-105): `init` allocates, `deinit` frees.
    pub fn init(allocator: std.mem.Allocator, problem: *const Problem, x0: []const f64) InitError!State {
        if (x0.len != problem.n) return error.LengthMismatch;
        const x = try allocator.alloc(f64, problem.n);
        errdefer allocator.free(x);
        const x_state = try allocator.alloc(VarState, problem.n);
        errdefer allocator.free(x_state);
        const x_mul = try allocator.alloc(f64, problem.n);
        errdefer allocator.free(x_mul);
        const f = try allocator.alloc(f64, problem.nf);
        errdefer allocator.free(f);
        const f_state = try allocator.alloc(VarState, problem.nf);
        errdefer allocator.free(f_state);
        const f_mul = try allocator.alloc(f64, problem.nf);
        errdefer allocator.free(f_mul);
        @memcpy(x, x0);
        @memset(x_state, .nonbasic_lower);
        @memset(x_mul, 0);
        @memset(f, 0);
        @memset(f_state, .nonbasic_lower);
        @memset(f_mul, 0);
        return .{ .x = x, .x_state = x_state, .x_mul = x_mul, .f = f, .f_state = f_state, .f_mul = f_mul };
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        allocator.free(self.x);
        allocator.free(self.x_state);
        allocator.free(self.x_mul);
        allocator.free(self.f);
        allocator.free(self.f_state);
        allocator.free(self.f_mul);
        self.* = undefined;
    }
};

/// Termination reason; values are the snOptA `INFO` codes (SRS-066).
pub const Exit = enum(u8) {
    optimal = 1,
    feasible_point = 2,
    accuracy_not_achieved = 3,
    infeasible_linear_constraints = 11,
    infeasible_linear_equalities = 12,
    nonlinear_infeasibilities_minimized = 13,
    infeasibilities_minimized = 14,
    infeasible_qp_subproblem = 15,
    unbounded_objective = 21,
    constraint_violation_limit = 22,
    iterations_limit = 31,
    major_iterations_limit = 32,
    superbasics_limit = 33,
    cannot_improve_point = 41,
    singular_basis = 42,
    cannot_satisfy_general_constraints = 43,
    ill_conditioned_null_space = 44,
    incorrect_objective_derivatives = 51,
    incorrect_constraint_derivatives = 52,
    undefined_at_first_feasible_point = 61,
    undefined_at_initial_point = 62,
    cannot_proceed_into_undefined_region = 63,
    user_terminated = 71,

    pub fn isSuccess(self: Exit) bool {
        return @backingInt(self) < 10;
    }

    /// snOptA groups codes by tens; e.g. 1 = infeasible, 3 = limits.
    pub fn category(self: Exit) u8 {
        return @backingInt(self) / 10;
    }
};

/// Solve summary (SRS-065); the iterate itself lives in `State`.
pub const Result = struct {
    exit: Exit,
    /// `obj_add + F[obj_row]`; zero for feasible-point problems.
    objective: f64,
    major_iterations: u32 = 0,
    minor_iterations: u32 = 0,
    /// Calls that requested `f`.
    function_evaluations: u32 = 0,
    /// Calls that requested `g`.
    jacobian_evaluations: u32 = 0,
    /// snOptA `nInf`/`sInf`: count and sum of remaining infeasibilities.
    num_infeasibilities: u32 = 0,
    sum_infeasibilities: f64 = 0,
    /// snOptA `nS`.
    superbasics: u32 = 0,
    /// Scaled max constraint violation and max dual infeasibility at exit.
    primal_infeasibility: f64 = 0,
    dual_infeasibility: f64 = 0,

    pub fn isSuccess(self: Result) bool {
        return self.exit.isSuccess();
    }
};

pub const Error = Problem.ValidateError || error{NotImplemented};

allocator: std.mem.Allocator,
problem: *const Problem,
options: Options,

/// Validates `problem` and sizes the workspace for it.
pub fn init(allocator: std.mem.Allocator, problem: *const Problem, options: Options) Error!Solver {
    try problem.validate(allocator);
    return .{ .allocator = allocator, .problem = problem, .options = options };
}

pub fn deinit(self: *Solver) void {
    self.* = undefined;
}

/// Runs the SQP method from `state`; `state` holds the solution on return.
pub fn solve(self: *Solver, state: *State, start: Start) Error!Result {
    _ = self;
    _ = state;
    _ = start;
    return error.NotImplemented;
}

// State construction procedure (TST-002).
test "State.init copies x0 and zeroes everything else" {
    const testing = std.testing;
    const low = [2]f64{ -1.0, -1.0 };
    const upp = [2]f64{ 1.0, 1.0 };
    const p = Problem{
        .n = 2,
        .nf = 2,
        .x_low = &low,
        .x_upp = &upp,
        .f_low = &low,
        .f_upp = &upp,
        .eval = struct {
            fn f(_: ?*anyopaque, _: Problem.Request) Problem.EvalError!void {}
        }.f,
    };
    var s = try State.init(testing.allocator, &p, &.{ 0.25, -0.5 });
    defer s.deinit(testing.allocator);
    try testing.expectEqual(@as(f64, 0.25), s.x[0]);
    try testing.expectEqual(@as(f64, -0.5), s.x[1]);
    try testing.expectEqual(@as(f64, 0.0), s.f_mul[1]);
    try testing.expectEqual(VarState.nonbasic_lower, s.x_state[0]);
    try testing.expectError(error.LengthMismatch, State.init(testing.allocator, &p, &.{1.0}));
}
