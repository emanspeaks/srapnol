//! Solver options. Defaults follow SNOPT 7 where a counterpart exists;
//! `docs/data-dictionary.md` maps each field to its SNOPT keyword (SRS-063).

const std = @import("std");

/// SNOPT `Derivative option`: whether every `G` entry is supplied.
pub const DerivativeOption = enum {
    /// Some `G` entries are left unset; they get finite-difference estimates.
    some_missing,
    all_provided,
};

/// SNOPT `Verify level`: finite-difference check of `G` before solving.
pub const VerifyLevel = enum(i8) {
    off = -1,
    cheap = 0,
    objective = 1,
    constraints = 2,
    all = 3,
};

pub const Hessian = enum { limited_memory, full_memory };

/// SNOPT `Scale option`.
pub const ScaleOption = enum(u8) {
    none = 0,
    /// Linear constraints and variables.
    linear = 1,
    /// Also nonlinear constraints and variables.
    all = 2,
};

/// SNOPT `Major iterations limit`.
major_iterations_limit: u32 = 1000,
/// SNOPT `Minor iterations limit`, per QP subproblem.
minor_iterations_limit: u32 = 500,
/// SNOPT `Iterations limit`, total minor iterations.
iterations_limit: u32 = 10_000,
/// SNOPT `Major feasibility tolerance`, nonlinear rows.
major_feasibility_tolerance: f64 = 1.0e-6,
/// SNOPT `Major optimality tolerance`.
major_optimality_tolerance: f64 = 1.0e-6,
/// SNOPT `Minor feasibility tolerance`, bounds and linear rows.
minor_feasibility_tolerance: f64 = 1.0e-6,
derivative_option: DerivativeOption = .all_provided,
verify_level: VerifyLevel = .off,
hessian: Hessian = .limited_memory,
/// SNOPT `Hessian updates`: pairs kept before a limited-memory reset.
hessian_updates: u32 = 10,
/// SNOPT `Elastic weight`: initial penalty on elastic infeasibility.
elastic_weight: f64 = 1.0e4,
/// SNOPT `Infinite bound`.
infinite_bound: f64 = 1.0e20,
scale_option: ScaleOption = .linear,
/// SNOPT `Function precision`, about eps^0.8.
function_precision: f64 = 3.0e-13,
/// SNOPT `Difference interval`, about eps^0.4.
difference_interval: f64 = 5.5e-7,
/// SNOPT `Central difference interval`, about eps^(1/3).
central_difference_interval: f64 = 6.7e-5,
/// SNOPT `Linesearch tolerance` in [0, 1); larger accepts looser steps.
linesearch_tolerance: f64 = 0.9,
/// SNOPT `Major step limit`: cap on the first line-search step, relative to `1 + ||x||`.
major_step_limit: f64 = 2.0,
/// SNOPT `Penalty parameter`: initial merit-function penalty.
penalty_parameter: f64 = 0.0,
/// SNOPT `Superbasics limit`; null picks `min(500, n + 1)`.
superbasics_limit: ?u32 = null,
/// SNOPT `Unbounded objective`.
unbounded_objective: f64 = 1.0e15,
/// SNOPT `Unbounded step size`.
unbounded_step_size: f64 = 1.0e18,
/// SNOPT `Violation limit`: cap on nonlinear constraint violation.
violation_limit: f64 = 10.0,
/// SNOPT `Major print level`; 0 is silent even with a writer.
major_print_level: u32 = 1,
/// SNOPT `Minor print level`.
minor_print_level: u32 = 0,
/// Iteration log destination; null disables all output.
writer: ?*std.Io.Writer = null,
