# Software Test Plan

| Field | Value |
| --- | --- |
| Identifier | SRAPNOL-STP |
| Revision | 0.1 (draft) |
| Date | 2026-09-15 |
| Software class | D; maintained for use by Class C applications |
| Prepared by | Randy Eckman, maintainer |
| Approved by | Maintainer, acting as Engineering Technical Authority |

Content follows NASA-HDBK-2203 topic 5.10 and satisfies SWE-065, SWE-066, and
SWE-191. Procedures are the TST Doorstop document; results are Software Test Reports.

## Revision history

| Revision | Date | Description |
| --- | --- | --- |
| 0.1 | 2026-09-15 | Initial plan. |

## 1. Test levels

| Level | Scope | Where |
| --- | --- | --- |
| Unit | One module or kernel: validation, `State` construction, SIMD kernels against scalar twins, the Jacobian oracle | `zig build test` (TST section 2) |
| Integration | The solver on a reference problem through the public API | `zig build test` (TST section 3) |
| System | Behavior across features: elastic mode, derivatives, warm starts, callback errors, diagnostics, size | `zig build test` (TST section 4) |
| Acceptance | The three-bar truss from the generic start with default options (TST-011) and the release portability matrix | `zig build test`; release checklist |

All automated levels live in one test binary; a level is a grouping of procedures, not
a separate build.

## 2. Test types

| Type | Applied as |
| --- | --- |
| Functional (requirements-based) | Every TST procedure links the SRS items it verifies; the published trace shows coverage |
| Regression | The whole suite is the regression suite: run locally before every push and in CI on every push to `main` (SWE-191) |
| Boundary | Validation rejections; infinite bounds; degenerate vertex (toy); a row and a bound active together (HS15) |
| Interface | C ABI round trip (TST-023); callback status sequence (TST-020) |
| Performance | Iteration counts and wall time per problem recorded, not asserted (TST-021) |
| Stress and endurance | Not applicable to a deterministic library with no external resources |
| Coverage | Requirements coverage from the trace matrix; code coverage measurement planned in phase 8 (SWE-189, SWE-190) |
| Embedded OSS | `rstd` runs its own suite (`zig build rstd-test`) with the project's (SWE-211) |

## 3. Test classes

Procedures are grouped by TST section: unit and static (2), reference problems (3),
behavioral (4), interface and delivery (5). Each procedure names its Zig test names or
manual steps.

## 4. Test environment

- Toolchain: self-built Zig at `C:\scratch\git\zig-build\bin\stage4\bin\zig.exe`
  (version recorded in the VDD); `zig build test` builds and runs the suite with the
  module's `build_options` and `rstd` imports.
- Dependencies: `rstd` vendored submodule at the pinned commit.
- Hardware: developer workstation (x86_64, Windows); the portability matrix adds
  Linux and macOS, x86_64 and aarch64, at release.
- Data: reference problems and their verified solutions in `src/test/`; the truss
  derivation in `src/test/example.md`.
- Tools for manual procedures: Doorstop (`pixi run doorstop`) for the citation
  inspection; a C compiler for the C ABI round trip.

## 5. Test progression and schedule

Procedures are added in the phase that implements their requirements (SDP section 5)
and stay in the suite thereafter. Solve procedures exist from phase 0 and skip while the
solver is a stub; they flip to passing in phases 3 through 7. The suite runs at every
push; a phase exits only with every non-skipped procedure passing and a Software Test
Report filed.

## 6. Acceptance criteria

- Every procedure whose SRS items are not all `pending` passes; no failures.
- A procedure may skip only while every SRS item it verifies has `status: pending`.
- Release additionally requires: TST-011 (truss acceptance) passing; requirements
  coverage 100% (every normative SRS item verified by Test has a passing procedure);
  no open high-severity problem report; the portability matrix passing.

## 7. Test coverage

Requirements coverage is read from the Doorstop trace (SRS items with TST children).
Code coverage: a measurement tool for Zig test binaries is selected in phase 8; until
then coverage is argued by the requirements trace and reviewed in code inspection.

## 8. Test witnessing

Not required (not safety-critical). Results are recorded automatically by the test
runner and transcribed to the STR.

## 9. Data recording, reduction, and analysis

The test runner output (pass, skip, fail per test) and the timing lines of the
performance procedure are pasted into the STR. Analysis compares against the previous
STR: new failures, changed skip counts, performance trend.

## 10. Risks and issues

- Round-off on the truss problem may make TST-011 flaky at `1e-6` tolerances before
  scaling is complete; mitigation R-1 in the SDP.
- No CI test runner for the self-built toolchain yet; local runs are the gate until a
  pinned release toolchain is available.

## 11. Qualification and personnel

Tests are run by the maintainer on the workstation; no external site or organization.
