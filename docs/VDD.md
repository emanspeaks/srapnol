# Version Description Document

| Field | Value |
| --- | --- |
| Identifier | SRAPNOL-VDD-0.1.0 |
| Software | `srapnol` 0.1.0 (pre-release baseline; solver stubbed) |
| Date | 2026-09-15 |
| Prepared by | Randy Eckman, maintainer |

Content follows NASA-HDBK-2203 topic 5.16 (SWE-063, SWE-077). One VDD is issued per
tagged release; this one describes the phase-0 baseline and serves as the template.

## a. Identification

- System: `srapnol`, SQP Reduced-Hessian Active-Set Partitioning Nonlinear
  Optimization Library.
- Version: `0.1.0` per `build.zig.zon`; package name `srapnol`; package fingerprint
  `0x2d43fb52de2942e8`.
- Baseline commit: the commit tagged `v0.1.0` (not yet tagged; the working baseline is
  branch `main`).
- Classification: Class D, not safety-critical.

## b. Executable software

None delivered; the product is a Zig source package. Build outputs: the `srapnol-test`
executable (`zig build`), the test binary (`zig build test`), and, from phase 9, the C
shared library and `srapnol.h` (`zig build shim`).

## c. Software life-cycle data

| Document | Identifier | Revision |
| --- | --- | --- |
| System requirements | SRAPNOL-SYS | 0.1 |
| Software Requirements Specification | SRAPNOL-SRS | 0.1 |
| Software Design Description | SRAPNOL-DES | 0.1 |
| Software Test Procedures | SRAPNOL-TST | 0.1 |
| Software Development/Management Plan | SRAPNOL-SDP | 0.1 |
| Requirements mapping matrix | SRAPNOL-RMM | 0.1 |
| Interface Design Description | SRAPNOL-IDD | 0.1 |
| Software Data Dictionary | SRAPNOL-SDD | 0.1 |
| Software Test Plan | SRAPNOL-STP | 0.1 |
| Software Test Report | SRAPNOL-STR-2026-09-15-phase0 | 1 |
| Software User Manual | SRAPNOL-SUM | 0.1 |
| Software Maintenance Plan | SRAPNOL-SMP | 0.1 |

## d. Archive and release data

- Repository: <https://github.com/emanspeaks/srapnol>, branch `main`, tags
  `vMAJOR.MINOR.PATCH`.
- Documentation site: published by the `docs` workflow to GitHub Pages from `main`.
- Vendored dependency: `vendor/rstd` submodule at the commit recorded in
  `.gitmodules` and the superproject tree.

## e. Build instructions

1. Install the Zig toolchain recorded below (self-built development version
   `0.17.0-dev.1864+4a4c0a4ed`; a released toolchain will be pinned at first release).
2. `git clone --recurse-submodules https://github.com/emanspeaks/srapnol.git`
3. `zig build` builds; `zig build test` runs the suite; `zig build docs` generates API
   documentation.
4. Documentation tools: `pixi install`, then `pixi run doorstop` to validate the
   requirement tree.

Recovery, regeneration, and modification follow the Software Maintenance Plan.

## f. Data integrity checks

Git commit SHA of the tag; `build.zig.zon` fingerprint `0x2d43fb52de2942e8`; Doorstop
review fingerprints on every requirement item; submodule commit pin.

## g. Software product files

`build.zig`, `build.zig.zon`, `build/`, `src/`, `LICENSE` (the package paths declared
in `build.zig.zon`); `docs/`, `AGENTS.md`, `readme.md`, `pixi.toml`, `.github/` for
maintenance.

## h. Open change requests and problem reports

None recorded. Known limitation: `Solver.solve` returns `error.NotImplemented`; all
solve procedures skip (SRS items with `status: surface` or `pending`).

## i. Completed changes since the previous version

Initial baseline: requirements, design, plans, test rig with five reference problems,
API surface (`Problem`, `Options`, `Solver` stub, `State`, `Result`, `Exit`).

## j. Security and coding-standard compliance

Source formatted with `zig fmt`; tests built in a safe mode; no external I/O; no static
analyzer run yet (planned, SDP section 4).
