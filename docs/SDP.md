# Software Development/Management Plan

| Field | Value |
| --- | --- |
| Identifier | SRAPNOL-SDP |
| Revision | 0.1 (draft) |
| Date | 2026-09-15 |
| Software | `srapnol`, SQP Reduced-Hessian Active-Set Partitioning Nonlinear Optimization Library |
| Software class | D (NPR 7150.2D Appendix D); maintained for use by Class C applications |
| Safety-critical | No |
| Prepared by | Randy Eckman, maintainer |
| Approved by | Maintainer, acting as Engineering Technical Authority |

Content follows NASA-HDBK-2203 topic 5.08. Sections that the handbook allows to be
separate plans (configuration management, risk, metrics, training, peer review,
security) are folded in here; the mapping matrix records which SWE items each
section satisfies.

## Revision history

| Revision | Date | Description |
| --- | --- | --- |
| 0.1 | 2026-09-15 | Initial plan; replaces the informal `roadmap.md`. |

## 1. Project organizational structure

`srapnol` is developed and maintained by a single maintainer who holds every role
below. The roles are named so that responsibilities are explicit and can be handed to
separate people if the project grows.

| Role | Responsibility | Holder |
| --- | --- | --- |
| Project manager | Plans, classification, this document, compliance matrix | Maintainer |
| Software engineer | Requirements, design, code, tests | Maintainer |
| Configuration manager | Baselines, releases, change control (section 19) | Maintainer |
| Verification lead | Test plan, procedures, reports | Maintainer |
| Software assurance | Assurance checklists per NASA-STD-8739.8, proportionate to Class D | Maintainer |
| Technical authority | Approves tailoring recorded in the mapping matrix | Maintainer |
| Users | Zig programs embedding the library; C-ABI consumers; Class C applications | External |

No hardware development, systems engineering, IV&V, subcontractor, or NESC involvement
exists.

## 2. Safety-critical determination and software classification

- **Classification (SWE-020, SWE-176).** Class D, "Basic Science/Engineering Design
  and Research and Technology Software": a ground-side engineering analysis library
  whose defects affect the productivity of its users, not mission objectives or safety.
  The project maintains the traceability, design documentation, and configuration
  control that Class C requires so a Class C application can incorporate the library
  without re-deriving that evidence.
- **Safety-critical determination (SWE-205, SWE-023).** Not safety-critical. The
  library controls no hardware, makes no decisions that affect people or equipment, and
  no system hazard traces to it. A host embedding it in a safety-critical function is
  responsible for its own hazard analysis; the library's fault-management behavior is
  specified in SRS sections 2.5 and 5.
- **Record.** This section and the repository history are the classification record;
  the determination is revisited at each release.

## 3. Tailored requirements mapping and compliance matrix

`compliance-matrix.md` lists every NPR 7150.2D requirement with its Class C and Class D
applicability, the project's approach, and evidence (SWE-121, SWE-125, SWE-139).
Tailoring for an independent open-source project without a NASA Center is recorded
there: no monetary cost estimate, no Center repository submission, no independent
assurance organization, and single-maintainer peer review.

## 4. Engineering environment

| Element | Choice |
| --- | --- |
| Language | Zig (self-built toolchain; version recorded in the VDD) |
| Build | `zig build` (`build/__root__.zig`); `zig build test` runs the suite; `zig build shim` (planned) builds the C shared library |
| Dependencies | Zig standard library; `rstd` (vendored submodule) |
| Coding standard (SWE-061) | `AGENTS.md` conventions, `.editorconfig`, `zig fmt`; requirement UIDs cited at fulfilling declarations |
| Secure coding (SWE-207) | Safe build modes for tests; no unchecked pointer casts outside the C shim, which validates every input; no I/O except the caller's writer |
| Static analysis (SWE-135, SWE-185) | Zig compile-time and safety checks and `zig fmt --check` now; analyzer selection planned in phase 8 |
| Requirements management | Doorstop 3.2 in the pixi environment (`pixi run doorstop`) |
| Documentation | Markdown with markdownlint (`npx markdownlint-cli2 "**/*.md"`), cspell; MkDocs site built in CI |
| Continuous integration | GitHub Actions: validate Doorstop tree, publish, deploy to GitHub Pages |
| Repository | <https://github.com/emanspeaks/srapnol>, branch `main` |
| Reference material | SNOPT/SQOPT user guides, GMS 2005, snopt7-examples, Hock-Schittkowski |

Tool accreditation (SWE-136): the toolchain and `rstd` versions are pinned in the VDD;
the test suite passing on the pinned toolchain is the accreditation evidence.

## 5. Work breakdown structure and schedule

The WBS is the phase sequence below. Phases are sequential because each builds on the
previous phase's kernels; within a phase, requirements are taken one at a time. A phase
exits when its procedures pass, the SRS `status` attributes are updated, a Software
Test Report is filed, and the Doorstop tree validates. No calendar dates are committed
(SWE-016 tailoring); effort is an estimate in maintainer-days.

| Phase | Scope | Closes (SRS sections / items) | Effort |
| --- | --- | --- | --- |
| 0 | Requirements, design, plans, test rig, API surface | Validation, callback adapter, silent output, constraints | done |
| 1 | Dense kernels: `vec.zig` with scalar twins, `dense.zig` LU/solves/Givens/Cholesky updates | 7 (scalar twins), 8 (SIMD constraints), 2.5 precision | 5 |
| 2 | Preprocessing: COO to CSC, option validation, slack formulation, partition, scaling, workspace sizing, callback wrapper | 2.1, 2.2 (feasible mode), 2.3, 4, 8 (storage) | 6 |
| 3 | QP solver: crash basis, dense LU basis, partition bookkeeping, `R`, pricing, EXPAND ratio test, feasibility phase | 2.4 (QP, basis, linear feasibility) | 10 |
| 4 | SQP driver: merit, line search, full-memory then limited-memory Hessian, termination, `Result` and multipliers | 2.4 (remaining), 3.1 (state, result, multipliers) | 10 |
| 5 | Infeasibility: elastic mode, violation limit; infeasible test variants | 2.2 (elastic), 2.4 (limits) | 4 |
| 6 | Derivatives: missing-derivative estimation, verify level, pattern estimation | 2.4 (derivatives), 3.3 (verify report) | 5 |
| 7 | Diagnostics and restarts: iteration log, exit summary, basis and warm starts | 3.3, 2.2 (starts) | 3 |
| 8 | Scale: HS118 and a synthetic 1000-variable problem; dense-basis limit; static analysis and coverage tooling | 4 (size), SWE-135/189 | 4 |
| 9 | Integration and delivery: `rstd.linalg` kernels, C ABI shim and shared-library build, portability matrix, first release | 3.2, 7 (portability), 10 | 8 |

Software size: about 1.5 kSLOC today; 8-10 kSLOC estimated at phase 9. Physical
resources: one developer workstation; CI runners for documentation and, later, tests.

## 6. Management of quality characteristics

| Characteristic | How it is managed |
| --- | --- |
| Correctness | Reference problems with independently verified optima; KKT checks before any solve; independent Jacobian oracle |
| Determinism and reliability | No randomness, no hidden allocation, no global state; determinism procedure |
| Maintainability | One module per component; requirement UIDs cited in code; design in DES |
| Portability | Pure Zig; portability procedure across the platform matrix |
| Performance | SIMD kernels; iteration counts and timing recorded per problem in STRs |
| Usability | SUM with the snOptA mapping; typed options and exits |

## 7. Management of safety, security, privacy, and other critical requirements

No safety-critical requirements (section 2). Security: the library performs no I/O
beyond the caller's writer and holds no persistent data (SRS section 6); the C shim
validates all inputs. Privacy: numerical arrays only, no personal data. Cybersecurity
assessment (SWE-156) is in section 14.

## 8. Subcontractor management

Not applicable; no subcontractors.

## 9. Verification

- **Methods and criteria (SWE-087, SWE-088, SWE-089).** Requirements, plans, design,
  code, and procedures are peer reviewed by checklist (section 21); tests are the TST
  procedures run by `zig build test`; inspection and analysis items are verified by
  review against DES and the source.
- **Work products verified.** SYS, SRS, DES, TST, this plan, STP, IDD, the data
  dictionary, source code, and the C header.
- **Environments.** Developer workstation for the suite; CI for documentation
  validation; the portability matrix at release.
- **Records.** Software Test Reports in `docs/reports/`; review records in pull
  requests; corrective actions as problem reports.

## 10. Validation

- **Methods (SWE-055).** Reference problems from the snOptA manual and the
  Hock-Schittkowski collection with solutions verified by closed-form KKT analysis; the
  truss acceptance case; comparison of options and exits with SNOPT documentation.
- **Work products validated.** The solver against the SRS; the SUM against the API.
- **Environment.** The test rig in `src/test/`.
- **Records.** Software Test Reports.

## 11. Project involvement in external development

Not applicable; no external developer.

## 12. User involvement

Users are represented by the snOptA interface contract and the reference problems. A
user-facing change (options, exits, C ABI) is a change request reviewed against the
SNOPT compatibility need (SYS) before implementation. Issues and pull requests on the
public repository are the user channel.

## 13. Risk management

Risks are recorded here, reviewed at each phase exit, and closed or re-scored
(SWE-086, tailored: no separate risk plan). Scoring is likelihood x consequence on a
1-3 scale.

| ID | Risk | L | C | Mitigation | Status |
| --- | --- | --- | --- | --- | --- |
| R-1 | Round-off in the truss problem (1e-4 variables, 1e8 rows) defeats the dual test | 2 | 3 | Scaling in phase 2; scaled tests assert unscaled quantities; GMS safeguards | Open |
| R-2 | Dense basis limits usable problem size | 3 | 2 | Basis interface designed for a sparse drop-in; phase 8 measures the limit | Open |
| R-3 | Zig toolchain churn (self-built dev version) breaks the build | 3 | 2 | Version pinned in the VDD; upgrade only at phase exits | Open |
| R-4 | Single maintainer: schedule and review independence | 3 | 2 | Checklist reviews; AI-assisted review recorded in PRs; public repository invites external review | Open |
| R-5 | `rstd` API changes at integration | 2 | 2 | Integration is the last phase; local kernels retained until equivalents are strict improvements | Open |
| R-6 | Supply chain: dependency or toolchain compromise | 1 | 2 | Vendored `rstd` submodule pinned by commit; self-built toolchain; no third-party packages | Open |

## 14. Security policy

All artifacts are public; no need-to-know controls apply. Write access to `main` is
limited to the maintainer; changes arrive by reviewed pull request. Cybersecurity
assessment (SWE-156): the library has no communications capability, opens no files,
and spawns no processes; the attack surface is malformed input, which validation and
the C shim's checks reject; residual risk is the supply chain (R-6). No adversarial
action detection applies (SWE-210).

## 15. Approvals required

Release to the public domain requires the maintainer's release checklist (section 19)
to pass. No regulatory approval or certification applies. Reuse (SWE-147, SWE-148):
the package is released for unrestricted reuse; contribution to the NASA software
catalog is evaluated at the first tagged release.

## 16. Process for scheduling, tracking, and reporting

Progress is tracked per phase against section 5: SRS `status` counts (pending,
surface, done), procedures passing, and open problem reports, all reported in the
phase-exit Software Test Report and summarized in this plan's revision history.
Re-planning is triggered when a phase's effort exceeds its estimate by half. No earned
value is computed (SWE-024 tailoring).

## 17. Training

Training is self-directed: SNOPT/SQOPT user guides and GMS 2005 for the method; the
Zig language reference for the toolchain; NASA-HDBK-2203 for documentation. Completed
study is noted in the phase-exit report (SWE-017 adopted for Class C compatibility; no
separate training plan).

## 18. Software life-cycle model

Incremental: the phases of section 5, each a requirements-to-test increment on the
same baseline. Reviews: a phase-exit review (procedures, traceability, STR); a release
review (section 19 checklist). Baselines: every merge to `main` is a baseline; releases
are tags. Integration with `rstd.linalg` and delivery are phase 9. Operations and
maintenance follow the Software Maintenance Plan.

## 19. Configuration management

Satisfies SWE-079 through SWE-085 (separate SCMP folded in per HDBK 5.06).

- **Organization and responsibilities.** The maintainer is the configuration manager
  and the change control board.
- **Configuration items (SWE-081).** Source (`src/`, `build/`, `build.zig*`), the
  documentation tree (`docs/`), `AGENTS.md`, `readme.md`, `pixi.toml`, CI workflows,
  the vendored `rstd` submodule commit, and the toolchain version recorded in the VDD.
- **Identification.** Git commits; releases tagged `vMAJOR.MINOR.PATCH` matching
  `build.zig.zon`; documents carry identifier and revision; Doorstop items carry UIDs
  and review fingerprints.
- **Configuration control (SWE-080, SWE-082).** Changes start as an issue (change
  request or problem report form); work happens on a branch; a pull request is reviewed
  against the section 21 checklist; requirement changes re-review the affected items
  and clear suspect links; merge to `main` is the approval. Authority: maintainer.
- **Status accounting (SWE-083).** Git history and tags; the VDD per release; Doorstop
  `reviewed` state; the SRS `status` attribute.
- **Audits (SWE-084).** Before each tag: tree validates with no errors, suite passes,
  markdownlint clean, VDD updated, compliance matrix reviewed, open problem reports
  listed in the VDD.
- **Storage, handling, delivery (SWE-085).** Public GitHub repository; releases are
  tags plus the published documentation site; the shared library and header are build
  outputs reproduced from the tag.
- **Build and release plan.** `zig build` reproduces every artifact from a tag; the
  release checklist above gates tagging.
- **Auto-generation tools (SWE-146).** The C header (generated by `zig build shim`)
  and the published documentation are generated from controlled sources and are not
  edited by hand.
- **Plan maintenance.** This section is revised with the plan; its revision history is
  the log.

## 20. Software document deliverables

The document register in `docs/README.md`. Relationships: SYS is the parent of SRS;
DES and TST are children of SRS; the SDP references STP, the maintenance plan, and the
mapping matrix; the VDD lists the document versions delivered with each release.

## 21. Software peer review and inspection process

Tailored for a single maintainer (SWE-087, SWE-088, SWE-089 adopted): every pull
request is reviewed by the maintainer against the checklist below, with AI-assisted
review recorded in the pull request when used; findings are fixed or filed as issues
before merge. Review measurements recorded in the pull request: items reviewed, time,
major and minor defects, disposition.

Checklist:

- Requirements: one `shall` per item, verifiable, traced to SYS, method assigned,
  rationale where non-obvious, no legacy IDs.
- Plans: sections complete per the HDBK topic; matrix updated.
- Design: each component links the SRS items it implements; references resolve.
- Code: cites the UIDs it fulfils; `zig fmt` clean; tests added or updated; no
  allocation in the solve loop; no I/O outside the writer.
- Procedures: fields complete; links to SRS; expected results quantitative.

## 22. Early identification of testing requirements

The acceptance problem (three-bar truss) and its severe scale disparity were chosen in
phase 0 specifically to drive the scaling and merit-function design; the test rig,
oracle, and reference solutions exist before any solver code so that each phase's
tests are known when its design is written.

## 23. Software metrics

Adopted for Class C compatibility (SWE-090, SWE-093, SWE-094, SWE-199; SWE-200
reported although not invoked).

| Measure | Format | Collected | Reported | Threshold |
| --- | --- | --- | --- | --- |
| Requirements by status | counts of pending/surface/done per SRS section | Doorstop tree, each phase exit | STR | phase exit criteria |
| Requirements coverage | SRS items with at least one TST link / total | Doorstop published trace | STR | 100% at release |
| Requirements volatility | items added, changed (fingerprint), removed since last report | git diff of `docs/srs` | STR | review if > 10% per phase |
| Tests | passed, skipped, failed | `zig build test` | STR | 0 failed; skips only for pending items |
| Problem reports | open by severity, closed | GitHub issues | STR, VDD | no open high severity at release |
| Performance | major/minor iterations, evaluations, wall time per reference problem | test rig output | STR | trend only |
| Size | SLOC per module | `cloc` or `wc` | VDD | trend only |
| Review measurements | items, time, defects per PR | PR template | phase exit | trend only |

Storage: the reports in `docs/reports/` and the repository; retention with the
repository. Analysis at each phase exit by the maintainer.

## 24. Software documentation content

Documents follow the minimum content of the NASA-HDBK-2203 topic named in the
register; conventions are in `docs/README.md`.

## 25. COTS, GOTS, MOTS, reused, and open-source software

| Component | Type | Use | Conditions (SWE-027) |
| --- | --- | --- | --- |
| Zig standard library | OSS (MIT) | allocation, SIMD, sort, I/O abstractions | Version pinned with the toolchain; defects tracked upstream and in the risk register |
| `rstd` | In-house OSS, vendored submodule | build utilities; `linalg` kernels at integration | Pinned by commit; its suite (`zig build rstd-test`) runs with the project's; defects assessed under R-5 |
| Doorstop, MkDocs | OSS, CI and documentation only | validation and publishing | Not delivered; versions pinned in the workflow |

Embedded OSS is tested to the same level as project code (SWE-211): `rstd` kernels
replacing local ones must pass the local kernels' tests.
