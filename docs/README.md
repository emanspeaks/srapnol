# Srapnol documentation set

Controlled documentation for `srapnol`, organized per NPR 7150.2D and NASA-HDBK-2203
(SWEHB Ver D) for Class D software maintained so Class C applications can adopt it.
Requirement-type documents are Doorstop trees (one item per file); narrative documents
are Markdown with a document-control block. Generated output is never committed; the
`docs` workflow validates the tree and publishes the site to GitHub Pages.

## Document register

| ID | Document | HDBK topic | Location | Status |
| --- | --- | --- | --- | --- |
| SRAPNOL-SYS | System requirements and stakeholder needs | 5.09 (parent) | `sys/` | Draft 0.1 |
| SRAPNOL-SRS | Software Requirements Specification | 5.09 | `srs/` | Draft 0.1 |
| SRAPNOL-DES | Software Design Description | 5.13 | `des/` | Draft 0.1 |
| SRAPNOL-TST | Software Test Procedures | 5.14 | `tst/` | Draft 0.1 |
| SRAPNOL-SDP | Software Development/Management Plan (with CM, risk, metrics, training, peer review, security) | 5.08, 5.06, 5.27, 5.05, 5.15, 5.03 | `SDP.md` | Draft 0.1 |
| SRAPNOL-RMM | NPR 7150.2D requirements mapping matrix | Appendix C | `compliance-matrix.md` | Draft 0.1 |
| SRAPNOL-IDD | Interface Design Description (C ABI) | 5.02 | `IDD.md` | Draft 0.1 |
| SRAPNOL-SDD | Software Data Dictionary | 5.07 | `data-dictionary.md` | Draft 0.1 |
| SRAPNOL-STP | Software Test Plan | 5.10 | `STP.md` | Draft 0.1 |
| SRAPNOL-STR | Software Test Reports | 5.11 | `STR-template.md`, `reports/` | Template + baseline |
| SRAPNOL-SUM | Software User Manual | 5.12 | `SUM.md` | Draft 0.1 |
| SRAPNOL-VDD | Version Description Document | 5.16 | `VDD.md` | 0.1.0 |
| SRAPNOL-SMP | Software Maintenance Plan | 5.04 | `maintenance-plan.md` | Draft 0.1 |
| SRAPNOL-CRPR | Change request / problem report | 5.01 | `.github/ISSUE_TEMPLATE/` | In use |

Not produced, with the reason recorded in the mapping matrix: Software Assurance Plan
and Safety Plan (not safety-critical; assurance folded into the SDP), IV&V plan (not
performed), Training Plan (folded into the SDP), separate Risk, Configuration
Management, and Metrics plans (folded into the SDP as HDBK 5.08 permits).

## Doorstop tree

```text
SYS  (root)   stakeholder needs and system requirements
 └─ SRS       software requirements, HDBK 5.09 outline
     ├─ DES   design components, each linking the SRS items it implements
     └─ TST   test procedures, each linking the SRS items it verifies
```

Conventions:

- Numeric UIDs (`SRS-001`) are requirements: normative items with a `shall`. Section
  headings and informative notes are non-normative items with word UIDs (`SRS-INTRO`,
  `SRS-PRB`, `SRS-PURPOSE`); they structure the published document and are never
  cited as requirements. Item files are Markdown with YAML front matter: the first `#`
  heading is the item header, the rest is the item text; headings have
  `level: x.y.0`.
- Extended attributes: `category`, `verification-method` (Test, Analysis, Inspection,
  Demonstration), `status` (`pending`, `surface`, `done`), `rationale`. `category`
  and `verification-method` contribute to the review fingerprint.
- `links` point only to the parent document. `references` on SRS items name the source
  file and the UID that must appear in it (see the requirement on requirement citation
  in SRS section 7); Doorstop verifies both.
- Changing an item's text changes its fingerprint; run `pixi run doorstop review <UID>`
  (or `all`) after reviewing, and `pixi run doorstop clear <UID>` on children whose
  parent changed once they have been re-examined.

Commands (from the repository root, inside the pixi environment):

```bash
pixi run docs-check    # validate the tree (doorstop --no-reformat)
pixi run docs-publish  # doorstop publish --markdown, then tools/fix_anchors.py
pixi run docs-serve    # tools/serve_docs.py: live-watches sources, serves at :3000
pixi run docs-watch    # standalone: republishes docs/build/req on source changes, no serve
```

`docs/build/` and `site/` are git-ignored. The CI workflow runs the same validation and
publish steps and builds the site with MkDocs from `mkdocs.yml`.

`mkdocs serve` alone only live-reloads on changes to `docs/build/req/*.md` (the
*published* tree), not `docs/{sys,srs,des,tst}/*.md` (the Doorstop *sources*) — editing
or committing an item does nothing to the served site until the "publish" pipeline
reruns. `pixi run docs-serve` (`tools/serve_docs.py`) closes that gap itself: it runs
`tools/watch_docs.py`'s poll-and-republish loop as a background thread in the same
process as `mkdocs serve`, so an edit shows up without a second terminal, and Ctrl+C
stops both together — no separate watcher process left running to remember to kill.
Narrative docs (`SDP.md` and the rest) have no such gap; MkDocs reads them directly.

Every heading Doorstop publishes carries a trailing `{#UID}` for the `attr_list`
Markdown extension (`mkdocs.yml` enables it) to turn into a clean `id="UID"` instead of
rendering it as literal text. Doorstop's own internal links (its per-document Table of
Contents, and each item's parent/child links) are computed against its *unadjusted*
slug of the whole heading line, so `tools/fix_anchors.py` rewrites them to the clean UID
after every publish — `pixi run docs-publish` always runs it; a bare
`doorstop publish ... --markdown` does not.

Each Software Test Report lives in `reports/` as its own file
(`STR-YYYY-MM-DD-label.md`, from `STR-template.md`); `mkdocs.yml`'s nav lists them
individually under Releases → Test reports, since MkDocs' nav is static. Adding a
report means adding its own nav entry alongside the others.

## Change control

Every document carries an identifier, revision, and date. Requirement changes go through
a change request (issue form), are made on a branch, reviewed against the checklist in
the SDP, and merged with the affected Doorstop items re-reviewed. The SDP change log
and git history are the status-accounting record.
