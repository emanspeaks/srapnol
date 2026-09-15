# srapnol

SQP Reduced-Hessian Active-Set Partitioning Nonlinear Optimization Library

A sparse nonlinear optimizer written from scratch in Zig, with a problem
interface modelled on `snOptA`: `F(x) = f(x) + A x`, bounds on `x` and `F`, a
constant sparse `A`, and a user-supplied sparse Jacobian `G` for the nonlinear part `f`.
The method is sequential quadratic programming (SQP) in the style of Gill, Murray, and
Saunders; see the Software Design Description in `docs/`.

## Documentation

`docs/README.md` is the register of the controlled documentation set (NPR 7150.2D,
NASA-HDBK-2203; Class D, maintained for Class C use): system and software
requirements, design, test procedures (Doorstop trees), the development plan,
compliance matrix, interface design, data dictionary, test plan, user manual, version
description, and maintenance plan. The `docs` workflow publishes the set to GitHub
Pages on every push to `main`.

## Layout

- `src/__root__.zig`: module root, also the test root.
- `src/Problem.zig`: problem definition, callback contract, validation.
- `src/Options.zig`: solver options with SNOPT-compatible defaults.
- `src/Solver.zig`: driver plus `State`, `Result`, `Exit`. Currently a stub returning `error.NotImplemented`.
- `src/test/support.zig`: the solve-or-skip shim, `F = f + A x` recombination, slice tolerance asserts, and a finite-difference Jacobian oracle.
- `src/test/truss.zig`, `toy.zig`, `hs47.zig`, `hs15.zig`, `hs76.zig`: test problems.
- `docs/`: the documentation set; `build/`: build script.

Build with `zig build`; run the suite with `zig build test` (the toolchain path is in
`AGENTS.md`).

## Test problems

| Problem | Source | What it exercises |
| --- | --- | --- |
| Three-bar truss | `src/test/example.md` | Primary acceptance case: objective entirely in `A`, dense nonlinear `G`, two-sided rows, one binding inequality, severe scale disparity (1e-4 variables, 1e8 rows, 1e12 Jacobian). |
| Toy (`sntoya`) | snopt7-examples | The snOptA manual's example; objective in `G` vs. in `A`; feasible-point mode; degenerate vertex. |
| HS47 | snopt7-examples `hs47a.f` | Equality rows mixing `A` and `G` in the same row; quartic objective with a slow tail. |
| HS15 | snopt7-examples `hs15.f` | Infeasible start; a bound and a row active together; multiplier signs. |
| HS76 | snopt7-examples `hs76.f` | Convex QP: linear rows in `A` only, quadratic objective in `G`; exact rational solution. |

Reference solutions come from the Hock-Schittkowski collection and from closed-form KKT
analysis. Each test file asserts the KKT conditions at the documented optimum before
anything is solved, so a wrong transcription fails now rather than after implementation.
The snopt7-examples sources are found in the [official Git repo](https://github.com/snopt/snopt7-examples).
