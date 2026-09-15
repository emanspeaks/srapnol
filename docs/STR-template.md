# Software Test Report template

Copy to `docs/reports/STR-YYYY-MM-DD-<label>.md` and fill every field. Content follows
NASA-HDBK-2203 topic 5.11 (SWE-065, SWE-068).

| Field | Value |
| --- | --- |
| Identifier | SRAPNOL-STR-YYYY-MM-DD-label |
| Software version | `build.zig.zon` version and git commit |
| Toolchain | Zig version; `rstd` commit |
| Date, time, location | |
| Personnel | Who ran the tests; witnesses (none unless stated) |

## 1. Overview of results

- **Conclusions.** Overall evaluation of the software as shown by the results.
- **Remaining deficiencies, limitations, constraints.** Impact on performance, design
  implications, recommended corrections.
- **Impact of the test environment.** Anything about the environment that affects
  interpretation.

## 2. Detailed results

| Procedure | Zig tests | Result (pass/skip/fail) | Requirements verified | Problems encountered | Deviations from the procedure |
| --- | --- | --- | --- | --- | --- |
| TST-nnn | | | SRS-nnn, ... | | |

## 3. Test log

- **Configuration.** Command line, build mode, platform, data storage location.
- **Activities.** Date and time of each run, who performed it.
- **Runner output.** Paste the summary lines of `zig build test`.

## 4. Measures

| Measure | Value |
| --- | --- |
| Tests passed / skipped / failed | |
| Requirements by status (pending / surface / done) | |
| Requirements coverage (SRS items with a passing procedure / total Test items) | |
| Requirements volatility since last report (added / changed / removed) | |
| Open problem reports by severity | |
| Performance per reference problem (majors, minors, evaluations, wall time) | |

## 5. Rationale for decisions

Why any result was accepted, waived, or deferred; references to problem reports.
