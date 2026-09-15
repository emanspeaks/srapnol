# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository.

## Build & run

- `zig` is not on `PATH` in this environment. The self-built toolchain lives at
  `C:\scratch\git\zig-build\bin\stage4\bin\zig.exe` (std lib at `C:\scratch\git\zig-build\lib\std`);
  invoke it by full path.
- `zig build test` runs the suite (a bare `zig test src/__root__.zig` cannot resolve the
  `rstd` and `build_options` imports).
- Python tooling (Doorstop, MkDocs) runs in a pixi environment; see `pixi.toml`.

## Dependencies

Never run a command that downloads or installs software without asking first and
getting explicit confirmation — package managers included (`pixi install`,
`pip install`, `npm install` for a new package, etc.), even when scoped to a
project-local environment (e.g. `.pixi/envs`) and even when it seems clearly implied
by the task at hand. This includes editing a manifest (`pixi.toml`, `package.json`,
`build.zig.zon`) to add a new dependency and then syncing it.

## Documentation and requirements

- Requirements, design, and test procedures are Doorstop trees under `docs/sys`,
  `docs/srs`, `docs/des`, and `docs/tst`, one Markdown item per file; plans and
  descriptions are Markdown documents in `docs/`. `docs/README.md` is the register and
  explains the conventions. Never edit `docs/build/` or `site/` (generated, git-ignored).
- Numeric UIDs (`SRS-001`) are requirements; word UIDs (`SRS-PRB`) are headings and notes.
  Code that fulfils a requirement cites its UID in the doc comment of the fulfilling
  declaration; test files cite their procedure (`TST-001`). Doorstop `references` on
  SRS items check those citations, so never remove or rename one without updating the item.
- After editing items run `pixi run docs-check` (Doorstop validation). After reviewing a
  changed item run `pixi run doorstop review <UID>`; after re-examining children of a
  changed parent run `pixi run doorstop clear <UID>`.
- A requirement change starts as a change-request issue and updates SRS/DES/TST before code.

## Markdown

There must never be markdownlint warnings or errors, in this file or any other Markdown file in the
repo. Config lives in `.markdownlint.jsonc` (rule overrides) and `.markdownlint-cli2.jsonc`. Before
finishing any task that touches a `.md` file, run:

```bash
npx markdownlint-cli2 "**/*.md"
```

Fix everything it reports — don't add rule suppressions to get around a finding unless the user
asks for it.

## Style conventions

- `.editorconfig` is authoritative — don't fight it.
- File naming: PascalCase filenames (`Terminal.zig`, `Graphics.zig`) for files whose main export is a
  single type/struct meant to be imported as that type; lowercase filenames (`acpi.zig`, `debug.zig`,
  `memory.zig`) for module-style files exposing multiple declarations.
- When a file's data is mechanically derived from an external source (e.g. Linux syscall tables), the
  doc comment must say where it came from (exact source file, commit/tag) and that it should be
  re-derived rather than hand-edited if it goes stale.
- Keep comments as short as possible.  Explanations should be brief bordering on terse.  No more than five lines per paragraph on average unless the explanation is truly remarkable to warrant long-windedness.

## Git

- Never run `git add` (or otherwise stage) after making edits, and never assume staging is a safe
  default just because committing isn't happening. Leave the working tree with unstaged changes, so
  the user can review them as an unstaged diff — auto-staged files disappear from that view, which
  reads as files randomly going missing mid-review. Only stage when explicitly asked to stage or
  commit.
- Never commit, pull, or perform any other sort of git operation with side effects unless explicitly asked to do so.  Checking git log or git diff are ok, changing branches or pushing are not.
- Never stage or unstage any files, even if directed by prompt.  Only allow the user to manually stage and unstage files.

## Spelling

`.cspell.jsonc` drives spell-checking; project-specific words go in
`.vscode/ltex.dictionary.en-US.txt` rather than being added as inline ignores, unless there's a good
reason to scope it more narrowly.  Do not add words to the dictionary yourself.
Do not worry about running spell-check yourself; it will be handled by the IDE.
