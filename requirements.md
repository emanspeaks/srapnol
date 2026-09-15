# Requirements

## 1. Scope and conventions

`srapnol` is a sparse, general nonlinear optimizer with a snOptA-style interface, written
strictly in Zig. This document is the contract the implementation is built and tested
against. Every requirement is identified, testable, and traced to a test in section 9.

- **Shall** is mandatory, **should** is recommended, **may** is optional.
- A numbered requirement (sections 2 through 7) shall contain at least one **shall**
  clause; that is what makes it binding. A goal that is not binding, such as a preference
  or a rationale, belongs in prose, not as a numbered item.
- IDs: `PRB` problem definition, `API` interface, `ALG` algorithm, `NUM` numerics and SIMD,
  `OUT` output and diagnostics, `IMP` implementation constraints, `TST` verification.
- Mathematical notation follows `theory.md`: `n` variables `x`, `nf` functions `F`,
  `F(x) = f(x) + A x`, Jacobian `J = G + A`, slacks `s`, multipliers `pi`.
- Design goal, not a requirement: keep dependencies minimal. Calling into `rstd` is fine;
  third-party packages are not (that part is binding, see IMP-1).
- Changing a requirement is a recorded decision: append to section 10.

## 2. Problem definition (PRB)

- **PRB-1 Problem form.** The solver shall solve `minimize F[obj_row](x) + obj_add`
  subject to `x_low <= x <= x_upp` and `f_low <= F(x) <= f_upp`, where
  `F(x) = f(x) + A x`, `x` in `R^n`, `F` in `R^nf`, `A` a constant sparse matrix, and
  `f` a smooth function with sparse Jacobian `G`.
- **PRB-2 Sparse coordinate input.** `A` shall be given as `(row, col, value)` triplets and
  the pattern of `G` as `(row, col)` pairs, in any order, 0-based. The solver shall not
  require sorted input.
- **PRB-3 Split evaluation contract.** The callback shall compute only `f(x)` and the `G`
  values in pattern order. It shall not add `A x`. The solver shall form
  `F = f + A x` and `J = G + A` itself. Rationale: linear terms are exact and are never
  re-differentiated; identical to snOptA.
- **PRB-4 Infinite bounds.** A bound with magnitude at or above `infinite_bound`
  (default `1e20`) shall be treated as absent.
- **PRB-5 Equalities and fixed variables.** `f_low[i] == f_upp[i]` shall define an
  equality row and `x_low[j] == x_upp[j]` a fixed variable, with no further user action.
- **PRB-6 Feasible-point mode.** `obj_row == null` shall request any point satisfying the
  constraints; the solver shall exit `feasible_point` with `objective == 0`.
- **PRB-7 Validation.** Before any callback, the solver shall reject with a distinct error:
  `n == 0` or `nf == 0`; slice lengths inconsistent with `n`/`nf`; `low > upp`; NaN in
  bounds or `A`; `obj_row >= nf`; row or column indices out of range; a duplicate slot
  within `A` or within `G`; the same slot in both `A` and `G`.
- **PRB-8 Callback statuses and errors.** The first call shall carry `status == .first`,
  exactly one final call after termination shall carry `.last` (with the final `x`,
  requesting nothing), all others `.normal`. `error.Undefined` shall mean "not evaluable
  here": the solver shall shorten the step and retry, exiting
  `undefined_at_initial_point`, `undefined_at_first_feasible_point`, or
  `cannot_proceed_into_undefined_region` when that fails. `error.Abort` shall terminate
  with `user_terminated`.
- **PRB-9 Row composition.** Any row, the objective included, may be entirely linear
  (all in `A`), entirely nonlinear (all in `G`), or mixed with disjoint columns. A row with
  no entries at all is constant and shall be checked for feasibility once.
- **PRB-10 Objective row bounds.** Bounds on the objective row shall be ignored, as in
  snOptA.

## 3. Interface (API)

- **API-1 Module surface.** `srapnol` shall expose `Problem`, `Options`, `Solver`, `State`,
  `Result`, `Exit`, `Start`, `VarState`, `infinity`, and `solve`. Nothing else is needed to
  use it.
- **API-2 Ownership and reentrancy.** `Solver.init(allocator, *const Problem, Options)`
  shall allocate all workspace from the given allocator; `deinit` shall free all of it.
  There shall be no global mutable state; independent `Solver` instances shall be usable
  concurrently from different threads.
- **API-3 Allocation policy.** After `init` returns, `solve` shall not allocate. Workspace
  size shall be a function of `n`, `nf`, `nnz(A)`, `nnz(G)`, and options only.
- **API-4 State.** `State` shall hold `x`, `x_state`, `x_mul`, `f`, `f_state`, `f_mul`.
  It is input for `basis`/`warm` starts and, on every exit, holds the final iterate: `x`,
  the full `F(x)`, states, and multipliers.
- **API-5 Start modes.** `cold` shall ignore states (crash basis), `basis` shall build the
  initial basis from the states, `warm` shall additionally use the multipliers and any
  retained Hessian information.
- **API-6 Options.** Every SNOPT option with a counterpart in this design shall be an
  `Options` field with SNOPT's default value (table in `api.md`). `init` shall reject
  invalid options (negative tolerances, `linesearch_tolerance` outside `[0, 1)`, zero
  limits) with `error.InvalidOption`.
- **API-7 Result.** `Result` shall report `exit`, `objective` (`obj_add + F[obj_row]`, or
  0), major and minor iteration counts, function and Jacobian evaluation counts, the count
  and sum of remaining infeasibilities, the number of superbasics, and the primal and dual
  infeasibility measures at exit.
- **API-8 Exit codes.** `Exit` shall be an enum whose integer values are the snOptA `INFO`
  codes; `isSuccess` shall be true for codes below 10; `category` shall be `code / 10`.
- **API-9 Errors versus exits.** Zig errors shall be reserved for misuse and resource
  failure (validation, `OutOfMemory`, `InvalidOption`). Every algorithmic outcome, failure
  to converge included, shall be an `Exit` value with `State` filled in.
- **API-10 Indexing.** All indices shall be 0-based.
- **API-11 Multiplier and state conventions.** At a reported solution,
  `grad F_obj(x) = sum over i != obj_row of f_mul[i] grad F_i(x) + x_mul`. `f_mul[i]` shall
  be `>= 0` when row `i` is at its lower bound and `<= 0` at its upper bound; `x_mul`
  likewise. `f_mul[obj_row]` shall be 0. `x_state`/`f_state` shall report the final active
  set with snOptA's encoding (`nonbasic_lower`, `nonbasic_upper`, `superbasic`, `basic`).
- **API-12 Diagnostics channel.** Output shall go only to `Options.writer`; a null writer
  shall mean no I/O of any kind.
- **API-13 Convenience entry.** `srapnol.solve(allocator, problem, options, state)` shall be
  exactly `init`, cold `solve`, `deinit`.
- **API-14 Typed callback adapter.** `Problem.wrap(Ctx, func)` shall adapt a
  `fn (*Ctx, Request) EvalError!void` to `EvalFn` at compile time, without allocation.
- **API-15 C ABI export.** `srapnol` shall additionally expose a C-callable interface: an
  adapter module, not a replacement, built from `extern "C"` functions over opaque handles,
  sufficient to build a `Problem` and `Options`, run `init`/`solve`/`deinit`, and read back
  `State`, `Result`, and `Exit`. The Zig-native surface (API-1) shall remain the primary
  interface; the C surface shall not change the allocation policy (API-3), determinism
  (NUM-8), or the zero-overhead callback dispatch (API-14) available to Zig callers.
- **API-16 C ABI callback and error convention.** The C interface's evaluation callback
  shall have signature `callconv(.c) fn (ctx: ?*anyopaque, req: *const CRequest, resp: *CResponse) callconv(.c) c_int`,
  returning 0 for success and distinct negative codes for `error.Undefined` and
  `error.Abort` (PRB-8), since C has no error unions. Every other Zig error or `Exit` value
  crossing the boundary shall likewise be a documented integer code, `Exit`'s codes (API-8)
  reused unchanged since they are already integers.

## 4. Algorithm (ALG)

- **ALG-1 Method.** The solver shall be an SQP method whose QP subproblems are solved by
  an active-set, reduced-Hessian (null-space) method with a quasi-Newton approximation of
  the Lagrangian Hessian, following Gill, Murray, and Saunders (2005) as laid out in
  `theory.md`.
- **ALG-2 Slack formulation.** Internally every row shall be posed as `F(x) - s = 0` with
  `f_low <= s <= f_upp`, so that all inequalities become simple bounds on `x` or `s`.
- **ALG-3 Linear feasibility first.** Before the first evaluation of `f`, the solver shall
  find a point satisfying the bounds and all entirely-linear rows to
  `minor_feasibility_tolerance`, exiting `infeasible_linear_constraints` or
  `infeasible_linear_equalities` when none exists. `f` shall never be evaluated at a point
  violating the bounds or the linear rows. Rationale: lets users rely on linear
  constraints to keep `f` defined, as SNOPT does.
- **ALG-4 QP subproblem.** At major iterate `(x_k, s_k, pi_k)` the QP shall minimize
  `g_k' d + 1/2 d' H_k d` over `d = x - x_k` subject to `F_k + J_k d - s = 0` and the
  bounds, solved by minor iterations that maintain a basic/superbasic/nonbasic partition
  and a dense Cholesky factor `R` of the reduced Hessian `Z' H Z`. The number of
  superbasics shall not exceed `superbasics_limit`.
- **ALG-5 Merit function and line search.** Steps shall be accepted by a line search on
  the augmented Lagrangian `M(x, s, pi) = f - pi'(F - s) + 1/2 (F - s)' D (F - s)` with a
  diagonal penalty `D` updated by the GMS rule. The search shall enforce sufficient
  decrease with `linesearch_tolerance` setting its accuracy, and the first trial step shall
  be capped by `major_step_limit`.
- **ALG-6 Hessian approximation.** The default shall be a limited-memory quasi-Newton
  approximation holding `hessian_updates` pairs before a reset; `full_memory` shall keep a
  dense BFGS factor for small `n`. Updates shall preserve positive definiteness with the
  GMS safeguards (modified update when curvature is insufficient, skip when that fails).
- **ALG-7 Elastic mode.** When the linearized rows are infeasible the solver shall switch
  to the elastic problem `minimize f + gamma e'(v + w)` with elastic variables `v, w >= 0`
  relaxing the nonlinear rows, starting from `elastic_weight` and increasing `gamma` on
  repeated infeasibility up to a cap; it shall exit `nonlinear_infeasibilities_minimized`
  or `infeasibilities_minimized` when the infeasibility is locally minimal and
  `infeasible_qp_subproblem` if a QP cannot be made feasible.
- **ALG-8 Termination.** The solver shall exit `optimal` when both hold: primal, the
  largest nonlinear row violation scaled by `1 + ||x||` is at most
  `major_feasibility_tolerance`; dual, the largest scaled complementarity or reduced
  gradient scaled by `max(1, ||pi||)` is at most `major_optimality_tolerance`. The exact
  norms follow the SNOPT manual and are pinned by the truss acceptance test (TST-4). It
  shall exit `feasible_point` in feasible-point mode once primal holds, and
  `iterations_limit`, `major_iterations_limit`, or `superbasics_limit` when a limit stops
  it.
- **ALG-9 Unboundedness and violation limits.** The solver shall exit `unbounded_objective`
  when the objective falls below `-unbounded_objective` or a step exceeds
  `unbounded_step_size`, and `constraint_violation_limit` when the nonlinear violation
  exceeds `violation_limit`.
- **ALG-10 Scaling.** `scale_option` shall select none, linear rows and variables, or all
  rows and variables, using iterative geometric-mean scaling (Fourer 1982, as in SNOPT).
  Scaling shall be invisible to the user: `State`, `Result`, and callbacks see unscaled
  quantities.
- **ALG-11 Missing derivatives.** With `derivative_option == .some_missing` the solver
  shall pre-fill `g` with NaN before each call and estimate every entry still NaN
  afterward by forward differences, switching to central differences near a solution.
  With `.all_provided`, a NaN left in `g` shall be reported as incorrect derivatives.
- **ALG-12 Derivative verification.** `verify_level` shall run a finite-difference check
  of `G` at the first linearly feasible point, over the rows SNOPT's levels select, and
  exit `incorrect_objective_derivatives` or `incorrect_constraint_derivatives` on failure.
- **ALG-13 Pattern estimation.** A routine equivalent to `snJac` shall estimate the `A`
  triplets and `G` pattern from the callback alone by finite differences at perturbed
  points. Lower priority than everything above.
- **ALG-14 Basis handling.** Cold starts shall build an initial basis by a crash procedure;
  the basis shall be factored by LU with partial pivoting, updated during minor iterations
  and refactored on demand; singular or ill-conditioned bases shall be repaired by
  swapping in slacks or reported as `singular_basis` / `ill_conditioned_null_space`.
- **ALG-15 Warm starts.** A `warm` start shall reuse the supplied states and multipliers
  as hints only; correctness of the result shall not depend on them.

## 5. Numerics and SIMD (NUM)

- **NUM-1 Precision.** All floating-point computation shall be in `f64`.
- **NUM-2 Vectorized dense kernels.** Dense vector operations (dot, axpy, scale, 2-norm,
  inf-norm, elementwise min/max/abs, bound projection, infeasibility sums) shall be
  implemented with `@Vector` of width `std.simd.suggestVectorLength(f64)` (scalar when
  null) plus scalar tails. Each kernel shall have a scalar reference twin and a test
  proving agreement to rounding on lengths 0, 1, `w - 1`, `w`, `w + 1`, and a large odd
  length, `w` being the lane width.
- **NUM-3 Sparse storage and products.** `A` and `G` shall be converted at `init` to a
  compressed-column layout with the pattern-order permutation retained, so callback `G`
  values are scattered without searching. Matrix-vector and transposed products shall use
  SIMD over contiguous value runs; gather/scatter may be scalar.
- **NUM-4 Vectorized dense factors.** Updates to the reduced-Hessian factor `R`
  (rank-one and Givens), triangular solves, and dense LU row operations shall use SIMD over
  rows or columns; pivot selection and rotation sequencing may be scalar.
- **NUM-5 Basis factorization.** The first implementation shall be a dense LU of the
  `nf x nf` basis. Its interface shall allow a sparse LU (LUSOL-style, Barrels-Golub
  updates) to replace it without changes to the QP solver. Dense is acceptable for
  `nf` up to about 2000.
- **NUM-6 Non-finite values.** NaN or infinity returned in `f` shall be treated as
  `error.Undefined`; no NaN shall be written to `State` on exit; every division by a
  quantity that can vanish shall be guarded.
- **NUM-7 Finite differences.** Forward steps shall be `difference_interval * (1 + |x_j|)`,
  central steps `central_difference_interval * (1 + |x_j|)`, with `function_precision`
  deciding when to switch.
- **NUM-8 Determinism.** Identical inputs shall give bit-identical outputs on the same
  target: no randomness (pattern estimation uses a fixed seed), no data races.
- **NUM-9 Conditioning safeguards.** `R` shall be kept positive definite (diagonal
  modification when an update fails) and its condition estimate monitored; a hopeless
  null space shall exit `ill_conditioned_null_space`.

## 6. Output and diagnostics (OUT)

- **OUT-1 Iteration log.** With a writer and `major_print_level > 0`, one fixed-width line
  per major iteration shall report: iteration, minors, step, evaluations, feasibility,
  optimality, merit, superbasics, penalty norm. `minor_print_level > 0` shall add
  minor-iteration lines.
- **OUT-2 Exit summary.** With a writer, the exit, objective, counts, and infeasibility
  measures shall be written once at termination.
- **OUT-3 Silent by default.** With a null writer there shall be no output of any kind,
  including debug printing.
- **OUT-4 Derivative report.** With a writer and `verify_level >= 0`, the worst declared
  error and the worst undeclared nonzero shall be reported with `(row, col)`.

## 7. Implementation constraints (IMP)

- **IMP-1 Zig only.** For internal implementation and functionality, the solver shall not
  use C, Fortran, assembly, FFI, or depend on third-party
  packages. The API-15 C-callable export is not an exception: it is Zig code compiled to
  present a C-compatible ABI, not a dependency on C code or a third-party library.
- **IMP-2 Requirement citation.** Code fulfilling a requirement shall cite its ID.
- **IMP-3 Borrowed input.** Slices in `Problem` shall remain valid for the life of the
  `Solver`, which shall never free them; `State` shall be caller-owned through
  `State.init`/`deinit`.
- **IMP-4 No panics on user input.** Every misuse detectable at `init` shall return an
  error; internal invariants may assert only in safe build modes.
- **IMP-5 C ABI buildability.** `build.zig` shall provide a build step that compiles the
  API-15 shim to a shared library (`.dll` on Windows, `.so`/`.dylib` elsewhere) exporting
  only its `extern "C"` symbols, alongside a generated C header. The step shall not require
  linking against libc or any other C runtime beyond what the target platform's dynamic
  loader itself needs.

## 8. Verification (TST)

Tests live in `src/test/`; names below are the Zig test names. The full suite is run with
`zig test src/__root__.zig` and shall pass with zero failures at every commit; this holds
by construction of section 9's traceability status and is not a separate requirement. A
solve test may skip only while the requirement it verifies is `pending` in that table; this
too is a consequence of the traceability status, not a requirement of its own.

- **TST-1 Truss invariant.** `sigma1 + sigma3 == sigma2` on a 5x5 logarithmic grid over
  the area bounds. `truss: sigma1 + sigma3 == sigma2 at every design point`.
- **TST-2 Truss Jacobian.** Analytic `G` matches central differences at the start, the
  optimum, and two other points to `1e-6`. `truss: analytic G matches central differences`.
- **TST-3 Truss benchmark.** The closed form reproduces `example.md` section 5, is a KKT
  point with only `sigma3` binding and `lambda > 0`, and the full `F` through the `A`/`G`
  split matches. `truss: documented optimum is the KKT point of the closed form`.
- **TST-4 Truss acceptance.** From `x0 = (5e-4, 5e-4)` with default options: `optimal`;
  `x` within `1e-5` relative; objective within `1e-6`; `sigma3` at its bound within `1e-6`
  relative; `f_state[3] == nonbasic_lower`; `f_mul[3]` within `1e-3` of `lambda*`.
  `truss: solve from the generic start reaches the benchmark optimum`.
- **TST-5 Toy problem.** Three layouts (objective in `G`, in `A`, feasible-point only)
  validate, agree on `F`, pass the Jacobian check, and solve to `(0, -1)` within `1e-6`;
  feasible-point mode exits `feasible_point`. `toy: *`.
- **TST-6 HS47.** Equality rows mixing `A` and `G` in one row; objective within `1e-6` of
  0, `x` within `1e-2` of all ones, rows within `1e-6`. `hs47: *`.
- **TST-7 HS15.** Infeasible start; `x`, objective, states of the active row and bound,
  and multipliers `pi = 700`, `mu = -1751`. `hs15: *`.
- **TST-8 HS76.** Convex QP with the exact solution `(3, 23, 0, 6)/11`, objective
  `-103/22`, states, and multipliers `pi = -5/11`, `mu = 19/11`. `hs76: *`.
- **TST-9 Validation negatives.** Each PRB-7 rejection has a test. `validate: *`.
- **TST-10 SIMD kernels.** Each NUM-2 kernel against its scalar twin on the required
  lengths. Pending with NUM-2.
- **TST-11 Jacobian oracle.** The test rig's own checker passes a correct `G` and flags a
  wrong value, a nonzero outside the pattern, and a linear term leaking into `f`.
  `jacobian oracle: *`.
- **TST-12 Infeasible variants.** The `hs47ModInf*` problems from snopt7-examples exit
  `nonlinear_infeasibilities_minimized` or `infeasibilities_minimized`. Pending with ALG-7.
- **TST-13 Missing derivatives.** The truss with `G` entries left NaN and
  `derivative_option == .some_missing` reaches the same optimum within looser tolerances.
  Pending with ALG-11.
- **TST-14 Verify level.** A deliberately wrong `G` entry exits
  `incorrect_constraint_derivatives`. Pending with ALG-12.
- **TST-15 Warm start.** Re-solving the truss from its own solution with `.warm` exits
  `optimal` within two major iterations. Pending with ALG-15.
- **TST-16 Callback errors.** `Abort` exits `user_terminated`; `Undefined` at `x0` exits
  `undefined_at_initial_point`. Pending with PRB-8.
- **TST-17 Scale.** HS118 (15 variables) and a synthetic sparse problem with about 1000
  variables solve within the iteration limits; exercises NUM-3 and the NUM-5 dense limit.
  Pending with NUM-5.
- **TST-18 C ABI round-trip.** A consumer that only sees the built shared library and its
  generated header (no `@import` of `srapnol` itself) solves the toy problem (TST-5)
  through the C interface and gets the same result as the native call. Pending with
  API-15, API-16, and IMP-5.

## 9. Traceability

Status: `pending` (not started), `surface` (types and signatures exist, behavior does
not), `done` (implemented and its tests pass).

| Requirement | Verified by | Status |
| --- | --- | --- |
| PRB-1, PRB-2, PRB-3 | TST-3, TST-4, TST-5, TST-6 | surface |
| PRB-4, PRB-5, PRB-9, PRB-10 | TST-4, TST-5, TST-6, TST-7 | surface |
| PRB-6 | TST-5 (feasible point only) | surface |
| PRB-7 | TST-9 | done |
| PRB-8 | TST-16 | surface |
| API-1, API-4, API-7, API-8, API-10, API-13 | all solve tests | surface |
| API-2, API-3, API-5, API-6, API-9, API-12 | TST-4, TST-15 | pending |
| API-11 | TST-4, TST-7, TST-8 | surface |
| API-14 | TST-11 and every test problem | done |
| API-15, API-16 | TST-18 | pending |
| ALG-1, ALG-2, ALG-4, ALG-5, ALG-6, ALG-8, ALG-14 | TST-4, TST-5, TST-6, TST-7, TST-8 | pending |
| ALG-3 | TST-8 (linear rows), TST-16 | pending |
| ALG-7, ALG-9 | TST-12 | pending |
| ALG-10 | TST-4 (scale disparity) | pending |
| ALG-11 | TST-13 | pending |
| ALG-12 | TST-14 | pending |
| ALG-13 | none yet | pending |
| ALG-15 | TST-15 | pending |
| NUM-1, NUM-6, NUM-8, NUM-9 | all solve tests | pending |
| NUM-2 | TST-10 | pending |
| NUM-3, NUM-5 | TST-17 | pending |
| NUM-4 | TST-8, TST-10 | pending |
| NUM-7 | TST-13 | pending |
| OUT-1, OUT-2, OUT-4 | manual inspection, later a golden-log test | pending |
| OUT-3 | all tests run silent | done |
| IMP-1, IMP-2, IMP-3 | review | done |
| IMP-4 | TST-9 | done |
| IMP-5 | TST-18 | pending |

## 10. Changelog

- 2026-09-15: initial requirements, API surface, and test rig; no solver behavior yet.
- 2026-09-15: reworded IMP-4 to drop "zero test failures," which is implicit in having a
  test suite rather than a distinct requirement; corrected stale paths
  (`src/linalg/srapnol/__root__.zig` to `src/__root__.zig`, `test/` to `src/test/`) left
  over from the pre-integration layout.
- 2026-09-15: added API-15/API-16 (C-callable shim over the Zig-native API, not a
  replacement for it) and IMP-8 (C ABI shared-library build step) with TST-18, after
  confirming the shim adds no measurable overhead over a C-ABI-native redesign: the
  callback-dispatch indirection is unavoidable for any DLL-supplied callback either way,
  and the shim only adds a negligible constant cost at `init`/`solve`/`deinit`, not in the
  numerical hot loops. Placed in roadmap.md phase 9, alongside the `rstd.linalg`
  integration.
- 2026-09-15: added the convention that a numbered requirement must contain a **shall**
  clause to be binding (section 1). Removed IMP-2 (self-containment) and IMP-4 (test skip
  policy), neither of which was ever a shall statement: IMP-2's intent is recorded as an
  unnumbered design goal in section 1 (minimize dependencies; `rstd` is fine, third-party
  packages are not, per IMP-1), and IMP-4's is folded into the unnumbered intro to section
  8 as a consequence of the traceability status rather than a requirement of its own.
  Reworded IMP-1, IMP-3, and IMP-6 (numbers as they stood before this entry's renumbering
  below), which had no **shall** clause despite being intended as binding, into proper
  "shall" statements without changing their meaning. Removed the now-dangling `IMP-2`
  references from the section 9 table and from `roadmap.md`.
- 2026-09-15: renumbered IMP to close the gaps left by removing IMP-2 and IMP-4: old
  IMP-3 to IMP-2, IMP-5 to IMP-3, IMP-6 to IMP-4, IMP-7 to IMP-5, IMP-8 to IMP-6. Updated
  every citation in `requirements.md`, `roadmap.md`, and `api.md`; no other document or
  source file cited these IDs.
- 2026-09-15: removed IMP-2 (Style) and trimmed IMP-3 (Documentation) to just its
  requirement-citation clause, renamed IMP-2. Doc comments, Markdown lint cleanliness, and
  file/comment style conventions are process hygiene an upstream engineering standard
  (the NPR 7150.2-style rigor this document is written to) already mandates generically;
  restating them here duplicated that obligation instead of adding a project-specific
  constraint. The one clause kept, "code fulfilling a requirement shall cite its ID," is
  this project's own traceability mechanism tying code to section 9, not something any
  upstream document would specify, so it survives as its own item rather than being cut
  with the rest. Renumbered the remaining IMP-4/IMP-5/IMP-6 down to IMP-3/IMP-4/IMP-5 and
  updated every citation in `requirements.md`, `roadmap.md`, and `api.md`.
