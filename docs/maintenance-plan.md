# Software Maintenance Plan

| Field | Value |
| --- | --- |
| Identifier | SRAPNOL-SMP |
| Revision | 0.1 (draft) |
| Date | 2026-09-15 |
| Prepared by | Randy Eckman, maintainer |
| Approved by | Maintainer, acting as Engineering Technical Authority |

Content follows NASA-HDBK-2203 topic 5.04 (SWE-075, SWE-080, SWE-195, SWE-196).

## 1. Maintenance activities

1. **Process implementation.** Feature requests and change requests arrive as GitHub
   issues using the change-request form; problem reports use the problem-report form.
   The maintainer triages weekly: accept, defer, or decline, with the reason on the
   issue.
2. **Problem and modification analysis.** Each accepted issue is analyzed for the SRS
   items affected (requirement change or defect), severity, and the procedures that
   must change; the analysis is recorded on the issue.
3. **Modification implementation.** On a branch: update SRS/DES/TST items first, then
   code and tests, citing UIDs; pull request reviewed against the SDP checklist.
4. **Maintenance review and acceptance.** The full suite passes; Doorstop validates;
   affected items re-reviewed; merge to `main` is acceptance.
5. **Migration.** A change of Zig toolchain or `rstd` version is a change request;
   the VDD records the new versions; the portability matrix is re-run.
6. **Retirement.** If the project is retired: final VDD, repository archived
   (read-only) with the documentation site left published, users notified through the
   repository README; residual support: none.
7. **Software assurance.** Test suites, reference data, and the documentation tree stay
   in the repository for the project's life; no licenses or simulators to transfer.
8. **Risk assessment.** Each modification is scored against the SDP risk register;
   changes to numerics require the full reference-problem suite and the determinism
   procedure.

## 2. Standards and methods

- Upgrade intervals: toolchain upgrades at phase exits or releases only.
- Scheduling: as issues are accepted; no fixed cadence.
- Equipment: developer workstation; CI runners.
- Documentation: updated in the same pull request as the change; VDD per release.
- Backup: the public repository and its forks; no separate archive.
- Operational modifications: none; the library has no operational deployment of its
  own.
- Delivery: tagged releases with VDD; the documentation site tracks `main`.
- Access to version data: public repository history and tags.
