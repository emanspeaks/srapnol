# Roadmap

Implementation order. Each phase closes the listed requirements and flips the listed
tests from skipped to passing. A phase is done when `zig test src/__root__.zig` is green
with those tests no longer skipping and `requirements.md` section 9 is updated. Phases are
sequential because each builds on the previous one's kernels; within a phase, requirements
are taken one at a time.

## Phase 0: requirements and test rig

- Requirements, API contract, theory, this roadmap.
- API surface: `Problem`, `Options`, `Solver` (stub), `State`, `Result`, `Exit`.
- Test problems with KKT-verified reference solutions: truss, toy, HS47, HS15, HS76.
- Independent finite-difference Jacobian oracle in `test/support.zig`.
- Closes PRB-7, API-14, OUT-3, and IMP-1 through IMP-4 as far as they apply to an empty solver.

## Phase 1: dense kernels

- `vec.zig`: `@Vector` kernels with scalar twins (NUM-2) and tests on the required lengths (TST-10).
- `dense.zig`: column-major helpers, LU with partial pivoting and solves, upper-triangular solves, Givens rotations, rank-one Cholesky update and downdate (NUM-4, NUM-9).
- Closes NUM-1, NUM-2, NUM-4 (kernels), NUM-8 (no randomness introduced).

## Phase 2: problem preprocessing

- `sparse.zig`: COO to CSC for `A` and `G` with the pattern-order permutation; mat-vec and transposed mat-vec (NUM-3).
- `Options` validation with `error.InvalidOption` (API-6).
- Slack formulation, linear/nonlinear partition of rows and columns, infinite-bound handling, objective-row removal (ALG-2, PRB-4, PRB-5, PRB-9, PRB-10).
- Scaling factors (ALG-10), applied and undone around the solve.
- Workspace sizing in `Solver.init` (API-2, API-3).
- Callback wrapper: status sequencing, NaN screening, `Undefined`/`Abort` mapping (PRB-8, NUM-6); TST-16.

## Phase 3: QP solver

- Crash basis, dense LU basis factor with an update/refactor policy, slack repair for singularity (ALG-14).
- Basic/superbasic/nonbasic bookkeeping, `Z` products, reduced gradient, dense `R`, pricing, ratio test with EXPAND, add and delete of superbasics (ALG-4).
- Feasibility phase for bounds and linear rows (ALG-3): exits 11 and 12.
- Internal tests: a QP with an explicit dense Hessian must reproduce HS76's exact solution in one call; LP feasibility on the linear rows of HS76 and HS47.

## Phase 4: SQP driver

- Major iteration loop, merit function with penalty updates, line search with `Undefined` back-off (ALG-5).
- Full-memory BFGS first (small `n`), then limited memory (ALG-6).
- Termination tests, limits, unboundedness (ALG-8, ALG-9); `Result` filling (API-7); multipliers and states out (API-11).
- Flips TST-4 (truss), TST-5 (toy, three layouts), TST-6 (HS47), TST-8 (HS76). TST-7 (HS15) may wait for phase 5 if its infeasible start needs elastic mode.
- Closes ALG-1, ALG-2, ALG-4, ALG-5, ALG-6, ALG-8, ALG-9, and API-1 through API-13.

## Phase 5: infeasibility

- Elastic mode with weight escalation (ALG-7): exits 13, 14, 15; `violation_limit` (ALG-9).
- Flips TST-7 if still pending and TST-12 (transcribe the `hs47ModInf*` problems from snopt7-examples).

## Phase 6: derivatives

- Missing-derivative detection and finite-difference estimation with column grouping (ALG-11, NUM-7); TST-13.
- Verify level with the solver's own checker, cross-checked against the oracle in `test/support.zig` (ALG-12, OUT-4); TST-14.
- Pattern estimation (ALG-13).

## Phase 7: diagnostics and restarts

- Iteration log and exit summary to `Options.writer` (OUT-1, OUT-2).
- `.basis` and `.warm` starts (API-5, ALG-15); TST-15.

## Phase 8: scale

- HS118 and a synthetic sparse problem (TST-17); profile the dense-basis limit (NUM-5).
- Sparse LU for the basis if that limit matters for the intended use.

## Phase 9: integration

- Export as `srapnol`; replace local kernels with `rstd.linalg.matlab` equivalents where they are a strict improvement.
- Wire the tests into `zig build rstd-test`.
- C-callable shim over the stabilized Zig API: opaque handles and `extern "C"` functions for `init`/`solve`/`deinit` and reading back `State`/`Result`/`Exit`, with the callback convention of API-16 (API-15, API-16).
- `build.zig` step that builds the shim as a shared library with a generated C header, without linking libc (IMP-5).
- Flips TST-18.
