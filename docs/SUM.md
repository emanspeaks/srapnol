# Software User Manual

| Field | Value |
| --- | --- |
| Identifier | SRAPNOL-SUM |
| Revision | 0.1 (draft) |
| Date | 2026-09-15 |
| Software | `srapnol` 0.1.0 |
| Prepared by | Randy Eckman, maintainer |

Content follows NASA-HDBK-2203 topic 5.12. Requirement identifiers refer to the SRS;
field-level detail (types, units, ranges, defaults) is in the Software Data Dictionary.

## Revision history

| Revision | Date | Description |
| --- | --- | --- |
| 0.1 | 2026-09-15 | Initial manual; replaces the informal `api.md`. |

## 1. Software summary

### 1.1 Application

`srapnol` solves sparse, general nonlinear programs

```text
minimize    F[obj_row](x) + obj_add
subject to  x_low <= x <= x_upp,   f_low <= F(x) <= f_upp,   F(x) = f(x) + A x
```

with `x` in `R^n`, `F` in `R^nf`, a constant sparse `A` given as triplets, and a
user-supplied `f` with sparse Jacobian `G`. The interface is modelled on `snOptA`; the
method is sequential quadratic programming with an active-set, reduced-Hessian QP
solver (Gill, Murray, Saunders 2005).

### 1.2 Inventory

A Zig package: `build.zig`, `build.zig.zon`, `build/`, `src/`, `LICENSE`. Public
declarations: `Problem`, `Options`, `Solver`, `State`, `Result`, `Exit`, `Start`,
`VarState`, `infinity`, `solve`. A C shared library and header are planned (IDD).

### 1.3 Environment

Any target the Zig toolchain recorded in the VDD supports. No runtime dependencies
beyond the Zig standard library and `rstd`.

### 1.4 Overview of operation

Build a `Problem` that borrows your arrays and names your callback; create a `Solver`
(validates and allocates once); create a `State` from a starting point; call `solve`;
read `Result` and `State`. Nothing is written anywhere unless you pass a writer.

### 1.5 Contingencies, states, and modes

Start modes: `cold` (crash basis), `basis` (use states), `warm` (states, multipliers,
Hessian memory). Feasible-point mode: `obj_row = null`. Every algorithmic outcome is an
`Exit` value; Zig errors mean misuse or resource failure only.

### 1.6 Security, privacy, assistance, problem reporting

No I/O beyond the writer; no persistent data. Report problems and request changes
through the GitHub issue forms (see `docs/README.md`).

## 2. Access to the software

### 2.1 First-time use

Add the package to your `build.zig.zon` (path or URL dependency) and import the module
in `build.zig`; `@import("srapnol")` in source. To build from a clone:
`git clone --recurse-submodules`, then `zig build`; `zig build test` runs the suite.

### 2.2 Initiating, stopping, and suspending

There is no session. A `Solver` may `solve` repeatedly with the same `Problem`, for
instance `.warm` from a previous `State`. To stop a solve early, return
`error.Abort` from the callback (exit `user_terminated`). `deinit` releases the
workspace; `State.deinit` releases the iterate.

## 3. Processing reference guide

### 3.1 Mapping from snOptA

| snOptA | srapnol | Notes |
| --- | --- | --- |
| `n`, `nF` | `Problem.n`, `Problem.nf` | Validated against slice lengths |
| `ObjRow` (0 = none) | `Problem.obj_row: ?u32` | `null` for a feasible-point problem |
| `ObjAdd` | `Problem.obj_add` | Reporting only |
| `iAfun, jAvar, A, neA` | `Problem.a: Linear` | `rows`, `cols`, `vals`; length is `neA` |
| `iGfun, jGvar, neG` | `Problem.g: Pattern` | `rows`, `cols`; the callback fills `neG` values in this order |
| `xlow, xupp, Flow, Fupp` | `x_low`, `x_upp`, `f_low`, `f_upp` | Magnitude at or above `infinity` means no bound |
| `usrfun(Status, n, x, needF, nF, F, needG, lenG, G, cu, iu, ru)` | `Problem.eval(ctx, Request)` | `Request.f`/`g` are null when not needed; `ctx` replaces `cu/iu/ru` |
| `Status` in/out | `Request.status`, `EvalError` | Statuses are an enum; "terminate" and "undefined" are errors |
| `x, xstate, xmul, F, Fstate, Fmul` | `State` | Same meaning; states are `VarState` |
| `Start` (Cold/Basis/Warm) | `Solver.Start` | Same three modes |
| `snInit`, `snSet*`, `snSpec` | `Options` | Defaults are SNOPT's; no spec-file parser |
| `INFO` | `Result.exit: Exit` | Same integer codes |
| `nS, nInf, sInf` | `Result.superbasics`, `num_infeasibilities`, `sum_infeasibilities` | Same meaning |
| `mincw, miniw, minrw`, workspaces | allocator in `Solver.init` | Sized automatically |
| `iPrint, iSumm` | `Options.writer` | One `*std.Io.Writer`, or null for silence |
| `snJac` | pattern estimation routine | Planned |
| `xnames, Fnames, Prob` | `Problem.name` | Only a problem name is kept |

### 3.2 Problem

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

Slices are borrowed for the life of the `Solver` and never freed by it.

Sparse conventions:

- `a` and `g` are coordinate lists in any order, 0-based. No slot may appear twice, and
  no slot may be in both; `validate` reports `DuplicateEntry` or `OverlappingEntry`.
- The callback writes `G` values in the order of `g.rows`/`g.cols`.
- A row may be all-`A`, all-`G`, or mixed. The objective row is not special: put its
  linear terms in `A` and its nonlinear terms in `G`.
- Bounds on the objective row are ignored; `f_low[i] == f_upp[i]` is an equality row;
  `x_low[j] == x_upp[j]` fixes a variable.

### 3.3 Callback contract

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

- Write `f` only if `req.f` is non-null and `g` only if `req.g` is non-null. Rows that
  are entirely linear get `0` in `f`.
- Never add `A x`; the solver does. The test rig's Jacobian oracle treats a nonzero
  difference at an `A` slot as an error.
- Return `error.Undefined` when `x` is outside the domain of `f`; the solver backs off.
  Return `error.Abort` to stop; the exit is `user_terminated`.
- `.first` arrives once before any other call; `.last` arrives once after termination
  with the final `x` and `f == g == null`.
- The callback may mutate its context through `ctx`.

`Problem.wrap(Ctx, func)` builds an `EvalFn` from a `fn (*Ctx, Request) EvalError!void`
at compile time:

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

Helpers: `validate(allocator)` (the structural checks; `Solver.init` calls it),
`evaluate(x, f, g, status)`, `addLinear(x, f)` (`f += A x`), `isInfinite(bound)`.

### 3.4 Options

Fields mirror SNOPT keywords with SNOPT defaults; the full table with types, units,
and ranges is in the Software Data Dictionary. Not carried over, by design:
`Solution`, `Print frequency`, `Summary frequency`, `Timing level`, `System
information`, basis-file options, `Sticky parameters`, `Proximal point method`,
`Crash option`/`Crash tolerance`, the `LU *` options, `Reduced Hessian dimension`,
`Pivot tolerance`, `Partial price`, `Expand frequency`, `Feasible point` (use
`obj_row = null`), `Minimize`/`Maximize` (negate in the callback). Additions are
change requests against the SRS.

### 3.5 Solver lifecycle

```zig
var solver = try srapnol.Solver.init(allocator, &problem, .{}); // validates, allocates workspace
defer solver.deinit();
var state = try srapnol.State.init(allocator, &problem, &x0);
defer state.deinit(allocator);
const result = try solver.solve(&state, .cold);
```

- `init` returns `Problem.ValidateError`, `error.InvalidOption`, or `OutOfMemory`. No
  callback runs during `init`.
- `solve` never allocates and never panics on user data. While the solver is a stub it
  returns `error.NotImplemented`; once implemented, every algorithmic outcome is an
  `Exit`.
- `srapnol.solve(allocator, &problem, options, &state)` wraps the three calls for
  one-shot use.

Start modes:

| `Start` | Uses from `State` | Notes |
| --- | --- | --- |
| `.cold` | `x` only | States and multipliers ignored; crash basis |
| `.basis` | `x`, `x_state`, `f_state` | Basis built from the states |
| `.warm` | everything | Also multipliers, and Hessian memory if retained |

### 3.6 State

| Field | Length | Input | Output |
| --- | --- | --- | --- |
| `x` | `n` | starting point | solution |
| `x_state` | `n` | basis hint (`.basis`, `.warm`) | active set |
| `x_mul` | `n` | multiplier hint (`.warm`) | bound multipliers |
| `f` | `nf` | ignored | full `F(x) = f(x) + A x` |
| `f_state` | `nf` | basis hint | active set |
| `f_mul` | `nf` | multiplier hint (`.warm`) | row multipliers |

Conventions: `VarState` is `nonbasic_lower` (0), `nonbasic_upper` (1), `superbasic`
(2), `basic` (3), the same integers as snOptA. Multiplier signs for minimization:
`>= 0` at a lower bound, `<= 0` at an upper bound, so that
`grad F_obj = sum over i != obj_row of f_mul[i] grad F_i + x_mul` at a solution;
`f_mul[obj_row]` is 0. `State.init(allocator, &problem, x0)` copies `x0` and zeroes the
rest; `deinit(allocator)` frees.

### 3.7 Result and Exit

`Result`: `exit`, `objective`, `major_iterations`, `minor_iterations`,
`function_evaluations`, `jacobian_evaluations`, `num_infeasibilities`,
`sum_infeasibilities`, `superbasics`, `primal_infeasibility`, `dual_infeasibility`;
`isSuccess()` forwards to `exit.isSuccess()`.

| `Exit` | Code | Meaning |
| --- | --- | --- |
| `optimal` | 1 | Optimality conditions satisfied |
| `feasible_point` | 2 | Feasible point found (`obj_row == null`) |
| `accuracy_not_achieved` | 3 | Requested accuracy could not be achieved |
| `infeasible_linear_constraints` | 11 | Bounds and linear rows have no common point |
| `infeasible_linear_equalities` | 12 | Linear equality rows are inconsistent |
| `nonlinear_infeasibilities_minimized` | 13 | Elastic mode: nonlinear infeasibility locally minimal |
| `infeasibilities_minimized` | 14 | Elastic mode: total infeasibility locally minimal |
| `infeasible_qp_subproblem` | 15 | A QP subproblem's linear constraints are infeasible |
| `unbounded_objective` | 21 | Objective below `-unbounded_objective` |
| `constraint_violation_limit` | 22 | Nonlinear violation above `violation_limit` |
| `iterations_limit` | 31 | Total minor iterations exhausted |
| `major_iterations_limit` | 32 | Major iterations exhausted |
| `superbasics_limit` | 33 | Superbasics limit exceeded |
| `cannot_improve_point` | 41 | Line search could not improve the merit function |
| `singular_basis` | 42 | Basis singular after repeated repair |
| `cannot_satisfy_general_constraints` | 43 | Could not satisfy the linearized constraints |
| `ill_conditioned_null_space` | 44 | Reduced-Hessian factor too ill-conditioned to continue |
| `incorrect_objective_derivatives` | 51 | Verify level found wrong objective derivatives |
| `incorrect_constraint_derivatives` | 52 | Verify level found wrong constraint derivatives |
| `undefined_at_first_feasible_point` | 61 | `error.Undefined` at the first linearly feasible point |
| `undefined_at_initial_point` | 62 | `error.Undefined` at `x0` |
| `cannot_proceed_into_undefined_region` | 63 | Step reduction could not leave the undefined region |
| `user_terminated` | 71 | Callback returned `error.Abort` |

`Exit.category()` returns the tens digit, matching snOptA's grouping; `isSuccess()` is
true for codes below 10.

### 3.8 Errors

| Error set | Where | Members |
| --- | --- | --- |
| `Problem.ValidateError` | `Problem.validate`, `Solver.init` | `NoVariables`, `NoFunctions`, `LengthMismatch`, `InvertedBounds`, `NonFiniteValue`, `ObjRowOutOfRange`, `IndexOutOfRange`, `DuplicateEntry`, `OverlappingEntry`, `OutOfMemory` |
| `Problem.EvalError` | callback | `Undefined`, `Abort` |
| `State.InitError` | `State.init` | `OutOfMemory`, `LengthMismatch` |
| `Solver.Error` | `Solver.init`, `Solver.solve` | `ValidateError` plus `NotImplemented` (stub only); `InvalidOption` when option validation lands |

### 3.9 Messages

With a writer and `major_print_level > 0`, one fixed-width line per major iteration
(iteration, minors, step, evaluations, feasibility, optimality, merit, superbasics,
penalty norm) and an exit summary; `minor_print_level > 0` adds minor lines;
`verify_level` reports the worst declared and undeclared derivative errors with their
`(row, col)`. With a null writer nothing is written.

### 3.10 Recovery from errors

A validation error means the `Problem` is malformed: fix the data and call `init`
again. An `Exit` other than `optimal`/`feasible_point` leaves the last iterate in
`State`; a `.warm` re-solve with adjusted options (looser tolerances, larger limits,
different scaling) is the usual recovery. `Undefined` exits mean `f` was not evaluable
near the start or along a step: add linear constraints or bounds that keep `f`
defined, since the solver never evaluates `f` outside them.

### 3.11 Departures from snOptA

Deliberate, and not to be "fixed": 0-based indices; `obj_row = null` instead of
`ObjRow = 0`; typed enums for states, statuses, options, and exits; callback failures
are Zig errors, not negative `Status` values; workspace from an allocator, no
`mincw/miniw/minrw` sizing step; one `writer` instead of Print and Summary units; no
spec-file parser; no variable or row names beyond `Problem.name`.

### 3.12 Example

`src/test/truss.zig` is the reference usage: a context struct owning its bound and
coefficient storage, a `problem()` method returning a `Problem` that borrows it, and a
`Solver`/`State` pair driving the solve. The problem's derivation and benchmark values
are in `src/test/example.md`.

## 4. Assumptions, limitations, and safety information

- `f` must be smooth on the region the bounds and linear rows admit; the solver never
  evaluates it outside that region.
- The dense basis factorization limits practical problems to about 2000 rows until the
  sparse factorization lands.
- Not safety-critical; a host embedding the library in a safety-critical function is
  responsible for its own hazard analysis. The library never panics on user data and
  reports every failure through `Exit`.
- Results are deterministic for identical inputs on the same target.

## 5. Version-specific information

0.1.0: API surface complete; `Solver.solve` returns `error.NotImplemented`; solve
procedures skip. See the VDD for the toolchain and the change list.
