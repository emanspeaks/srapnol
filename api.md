# API

The contract for using `srapnol`. Requirement IDs refer to `requirements.md`.
Everything is 0-based (API-10) and in `f64` (NUM-1).

## 1. Mapping from snOptA

| snOptA | srapnol | Notes |
| --- | --- | --- |
| `n`, `nF` | `Problem.n`, `Problem.nf` | Validated against slice lengths. |
| `ObjRow` (0 = none) | `Problem.obj_row: ?u32` | `null` for a feasible-point problem. |
| `ObjAdd` | `Problem.obj_add` | Reporting only. |
| `iAfun, jAvar, A, neA` | `Problem.a: Linear` | `rows`, `cols`, `vals` slices; their length is `neA`. |
| `iGfun, jGvar, neG` | `Problem.g: Pattern` | `rows`, `cols`; the callback fills `neG` values in this order. |
| `xlow, xupp, Flow, Fupp` | `Problem.x_low`, `x_upp`, `f_low`, `f_upp` | Magnitude at or above `infinity` means no bound. |
| `usrfun(Status, n, x, needF, nF, F, needG, lenG, G, cu, iu, ru)` | `Problem.eval(ctx, Request)` | `Request.f`/`g` are null when not needed; `ctx` replaces `cu/iu/ru`. |
| `Status` in/out | `Request.status`, `EvalError` | Statuses are an enum; "terminate" and "undefined" are errors. |
| `x, xstate, xmul, F, Fstate, Fmul` | `State` | Same meaning; states are `VarState`. |
| `Start` (Cold/Basis/Warm) | `Solver.Start` | Same three modes. |
| `snInit`, `snSet*`, `snSpec` | `Options` struct | Defaults are SNOPT's; no spec-file parser yet. |
| `INFO` | `Result.exit: Exit` | Same integer codes. |
| `nS, nInf, sInf` | `Result.superbasics`, `num_infeasibilities`, `sum_infeasibilities` | Same meaning. |
| `mincw, miniw, minrw`, workspaces | `std.mem.Allocator` in `Solver.init` | Sized automatically. |
| `iPrint, iSumm` | `Options.writer` | A single `*std.Io.Writer`, or null for silence. |
| `snJac` | pattern estimation routine | Planned (ALG-13). |
| `xnames, Fnames`, `Prob` | `Problem.name` | Only a problem name is kept. |

## 2. Problem

`Problem` is a plain struct of borrowed slices (IMP-3) plus a callback.

```zig
pub const Problem = struct {
    n: usize,
    nf: usize,
    obj_row: ?u32 = null,
    obj_add: f64 = 0,
    x_low: []const f64,
    x_upp: []const f64,
    f_low: []const f64,
    f_upp: []const f64,
    a: Linear = .{}, // rows, cols, vals
    g: Pattern = .{}, // rows, cols
    eval: EvalFn,
    ctx: ?*anyopaque = null,
    name: []const u8 = "",
};
```

### 2.1 Sparse conventions

- `a` and `g` are coordinate lists in any order (PRB-2). No slot may appear twice, and no slot may be in both; `validate` reports `DuplicateEntry` or `OverlappingEntry` (PRB-7).
- The callback writes `G` values in the order of `g.rows`/`g.cols` (PRB-3).
- A row may be all-`A`, all-`G`, or mixed (PRB-9). The objective row is not special: put its linear terms in `A` and its nonlinear terms in `G`.

### 2.2 Callback contract

```zig
pub const Request = struct {
    x: []const f64, // length n
    f: ?[]f64, // length nf when non-null: write f(x), the nonlinear part only
    g: ?[]f64, // length g.len() when non-null: write G in pattern order
    status: Status, // .first, .normal, .last
};
pub const EvalError = error{ Undefined, Abort };
pub const EvalFn = *const fn (ctx: ?*anyopaque, req: Request) EvalError!void;
```

Rules:

- Write `f` only if `req.f` is non-null and `g` only if `req.g` is non-null. Rows that are entirely linear get `0` in `f`.
- Never add `A x` (PRB-3). The test rig's Jacobian oracle treats a nonzero difference at an `A` slot as an error.
- Return `error.Undefined` when `x` is outside the domain of `f`; the solver backs off (PRB-8). Return `error.Abort` to stop; the exit is `user_terminated`.
- `.first` arrives once before any other call; `.last` arrives once after termination with the final `x` and `f == g == null`.
- The callback may mutate its context (evaluation counters, caches) through `ctx`.

`Problem.wrap(Ctx, func)` builds an `EvalFn` from a `fn (*Ctx, Request) EvalError!void` (API-14):

```zig
const Truss = struct {
    fn eval(self: *Truss, req: Problem.Request) Problem.EvalError!void {
        // ...
    }

    fn problem(self: *Truss) Problem {
        return .{
            // ... dimensions, bounds, a, g ...
            .eval = Problem.wrap(Truss, eval),
            .ctx = self,
        };
    }
};
```

### 2.3 Helpers

- `validate(allocator)`: the PRB-7 checks; the allocator is scratch for the duplicate scan. `Solver.init` calls it.
- `evaluate(x, f, g, status)`: calls the callback with the stored `ctx`.
- `addLinear(x, f)`: `f += A x`, turning the callback's `f` into the full `F`.
- `isInfinite(bound)`.

## 3. Options

Fields, their SNOPT keyword, and defaults (API-6). Units and meanings follow SNOPT.

| Field | SNOPT keyword | Default | Notes |
| --- | --- | --- | --- |
| `major_iterations_limit` | Major iterations limit | 1000 | |
| `minor_iterations_limit` | Minor iterations limit | 500 | Per QP subproblem. |
| `iterations_limit` | Iterations limit | 10000 | Total minor iterations. |
| `major_feasibility_tolerance` | Major feasibility tolerance | 1e-6 | Nonlinear rows. |
| `major_optimality_tolerance` | Major optimality tolerance | 1e-6 | |
| `minor_feasibility_tolerance` | Minor feasibility tolerance | 1e-6 | Bounds and linear rows. |
| `derivative_option` | Derivative option | `.all_provided` (1) | `.some_missing` is 0. |
| `verify_level` | Verify level | `.off` (-1) | `.cheap` 0, `.objective` 1, `.constraints` 2, `.all` 3. |
| `hessian` | Hessian full memory / limited memory | `.limited_memory` | |
| `hessian_updates` | Hessian updates | 10 | Pairs before a limited-memory reset. |
| `elastic_weight` | Elastic weight | 1e4 | |
| `infinite_bound` | Infinite bound | 1e20 | |
| `scale_option` | Scale option | `.linear` (1) | `.none` 0, `.all` 2. |
| `function_precision` | Function precision | 3.0e-13 | |
| `difference_interval` | Difference interval | 5.5e-7 | |
| `central_difference_interval` | Central difference interval | 6.7e-5 | |
| `linesearch_tolerance` | Linesearch tolerance | 0.9 | |
| `major_step_limit` | Major step limit | 2.0 | |
| `penalty_parameter` | Penalty parameter | 0.0 | |
| `superbasics_limit` | Superbasics limit | null | Means `min(500, n + 1)`. |
| `unbounded_objective` | Unbounded objective | 1e15 | |
| `unbounded_step_size` | Unbounded step size | 1e18 | |
| `violation_limit` | Violation limit | 10.0 | |
| `major_print_level` | Major print level | 1 | |
| `minor_print_level` | Minor print level | 0 | |
| `writer` | Print file / Summary file | null | `?*std.Io.Writer`; null is silent. |

Not carried over, by design: `Solution`, `Print frequency`, `Summary frequency`, `Timing level`, `System information`, the basis-file options, `Sticky parameters`, `Proximal point method`, `Crash option`/`Crash tolerance` (the crash procedure is fixed for now), the `LU *` options (the first basis factorization is dense), `Reduced Hessian dimension`, `Pivot tolerance`, `Partial price`, `Expand frequency` (fixed per `theory.md`), `Feasible point` (use `obj_row = null`), `Minimize`/`Maximize` (negate in the callback; may be added later). Additions are recorded in `requirements.md` section 10.

## 4. Solver lifecycle

```zig
var solver = try srapnol.Solver.init(allocator, &problem, .{}); // validates, allocates workspace
defer solver.deinit();
var state = try srapnol.State.init(allocator, &problem, &x0);
defer state.deinit(allocator);
const result = try solver.solve(&state, .cold);
```

- `init` returns `Problem.ValidateError`, `error.InvalidOption` (API-6, planned), or `OutOfMemory`. No callback runs during `init`.
- `solve` never allocates (API-3) and never panics on user data (IMP-4). While stubbed it returns `error.NotImplemented`; once implemented, every algorithmic outcome is an `Exit` (API-9).
- A `Solver` may `solve` repeatedly with the same `Problem`, e.g. `.warm` from a previous `State`.
- `srapnol.solve(allocator, &problem, options, &state)` wraps the three calls for one-shot use (API-13).

### 4.1 Start modes

| `Start` | Uses from `State` | Notes |
| --- | --- | --- |
| `.cold` | `x` only | States and multipliers ignored; crash basis. |
| `.basis` | `x`, `x_state`, `f_state` | Basis built from the states. |
| `.warm` | everything | Also multipliers, and Hessian memory if retained. |

## 5. State

| Field | Length | Input | Output |
| --- | --- | --- | --- |
| `x` | `n` | starting point | solution |
| `x_state` | `n` | basis hint (`.basis`, `.warm`) | active set |
| `x_mul` | `n` | multiplier hint (`.warm`) | bound multipliers |
| `f` | `nf` | ignored | full `F(x) = f(x) + A x` |
| `f_state` | `nf` | basis hint | active set |
| `f_mul` | `nf` | multiplier hint (`.warm`) | row multipliers |

Conventions (API-11):

- `VarState`: `nonbasic_lower` (0), `nonbasic_upper` (1), `superbasic` (2), `basic` (3); the same integers as snOptA's `xstate`/`Fstate`.
- Multiplier signs for minimization: `>= 0` at a lower bound, `<= 0` at an upper bound, so that `grad F_obj = sum over i != obj_row of f_mul[i] grad F_i + x_mul` at a solution. `f_mul[obj_row]` is 0.
- `State.init(allocator, &problem, x0)` copies `x0` and zeroes the rest; `deinit(allocator)` frees.

## 6. Result and Exit

`Result` fields: `exit`, `objective`, `major_iterations`, `minor_iterations`, `function_evaluations`, `jacobian_evaluations`, `num_infeasibilities`, `sum_infeasibilities`, `superbasics`, `primal_infeasibility`, `dual_infeasibility`. `isSuccess()` forwards to `exit.isSuccess()`.

| `Exit` | Code | Meaning |
| --- | --- | --- |
| `optimal` | 1 | Optimality conditions satisfied. |
| `feasible_point` | 2 | Feasible point found (`obj_row == null`). |
| `accuracy_not_achieved` | 3 | Requested accuracy could not be achieved. |
| `infeasible_linear_constraints` | 11 | Bounds and linear rows have no common point. |
| `infeasible_linear_equalities` | 12 | Linear equality rows are inconsistent. |
| `nonlinear_infeasibilities_minimized` | 13 | Elastic mode: nonlinear infeasibility locally minimal. |
| `infeasibilities_minimized` | 14 | Elastic mode: total infeasibility locally minimal. |
| `infeasible_qp_subproblem` | 15 | A QP subproblem's linear constraints are infeasible. |
| `unbounded_objective` | 21 | Objective below `-unbounded_objective`. |
| `constraint_violation_limit` | 22 | Nonlinear violation above `violation_limit`. |
| `iterations_limit` | 31 | Total minor iterations exhausted. |
| `major_iterations_limit` | 32 | Major iterations exhausted. |
| `superbasics_limit` | 33 | Superbasics limit exceeded. |
| `cannot_improve_point` | 41 | Line search could not improve the merit function. |
| `singular_basis` | 42 | Basis singular after repeated repair. |
| `cannot_satisfy_general_constraints` | 43 | Could not satisfy the linearized constraints. |
| `ill_conditioned_null_space` | 44 | Reduced-Hessian factor too ill-conditioned to continue. |
| `incorrect_objective_derivatives` | 51 | Verify level found wrong objective derivatives. |
| `incorrect_constraint_derivatives` | 52 | Verify level found wrong constraint derivatives. |
| `undefined_at_first_feasible_point` | 61 | `error.Undefined` at the first linearly feasible point. |
| `undefined_at_initial_point` | 62 | `error.Undefined` at `x0`. |
| `cannot_proceed_into_undefined_region` | 63 | Step reduction could not leave the undefined region. |
| `user_terminated` | 71 | Callback returned `error.Abort`. |

`Exit.category()` returns the tens digit, matching snOptA's grouping.

## 7. Errors

| Error set | Where | Members |
| --- | --- | --- |
| `Problem.ValidateError` | `Problem.validate`, `Solver.init` | `NoVariables`, `NoFunctions`, `LengthMismatch`, `InvertedBounds`, `NonFiniteValue`, `ObjRowOutOfRange`, `IndexOutOfRange`, `DuplicateEntry`, `OverlappingEntry`, `OutOfMemory` |
| `Problem.EvalError` | callback | `Undefined`, `Abort` |
| `State.InitError` | `State.init` | `OutOfMemory`, `LengthMismatch` |
| `Solver.Error` | `Solver.init`, `Solver.solve` | `ValidateError` plus `NotImplemented` (stub only); `InvalidOption` arrives with API-6 |

## 8. Departures from snOptA

Deliberate, and not to be "fixed":

- 0-based indices; `obj_row = null` instead of `ObjRow = 0`.
- Typed enums for states, statuses, options, and exits instead of integer codes and keyword strings.
- Callback failures are Zig errors, not negative `Status` values.
- Workspace comes from an allocator; there is no `mincw/miniw/minrw` sizing step.
- One `writer` instead of Print and Summary file units.
- No spec-file parser (a helper that fills `Options` from text may come later).
- No variable or row names beyond `Problem.name`.

## 9. Example

`test/truss.zig` is the reference usage: a context struct owning its bound and coefficient storage, a `problem()` method returning a `Problem` that borrows it, and a `Solver`/`State` pair driving the solve.
