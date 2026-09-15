# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository.

## Build & run

- `zig` is not on `PATH` in this environment. The self-built toolchain lives at
  `C:\scratch\git\zig-build\bin\stage4\bin\zig.exe` (std lib at `C:\scratch\git\zig-build\lib\std`);
  invoke it by full path.

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
