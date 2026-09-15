"""Insert last-changed-by/when metadata into published Doorstop items from git.

Doorstop tracks no per-item author or date -- only a content fingerprint. This adds
a "*Last changed: YYYY-MM-DD by Author (abc1234)*" line under each item's heading,
read from the git history of that item's own source file (docs/sys/UID.md etc.), the
only place this project actually records who changed a requirement and when. An item
never committed gets no line -- git has no history for it yet. The abbreviated hash
links to the commit on the hosting site (GitHub, GitLab, Gitea/Codeberg, ...),
detected from the `origin` remote URL; if the remote is missing or unrecognized, the
hash is shown as plain text instead.

The same per-*document* metadata (not per-item) is added to the narrative docs by the
MkDocs build hook in tools/mkdocs_hooks.py.

Usage: python tools/add_edit_metadata.py <published-dir>
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from git_metadata import REPO_ROOT, last_change, resolve_remote  # noqa: E402

SOURCE_DIRS = ["sys", "srs", "des", "tst"]
HEADING = re.compile(r"^(#{1,6} .*\{#([\w-]+)\})[ \t]*$", re.MULTILINE)


def main() -> None:
    root = Path(sys.argv[1])
    remote = resolve_remote()

    metadata: dict[str, str] = {}
    for sub in SOURCE_DIRS:
        for path in sorted((REPO_ROOT / "docs" / sub).glob("*.md")):
            note = last_change(path, remote)
            if note:
                metadata[path.stem] = note

    def repl(match: re.Match) -> str:
        note = metadata.get(match.group(2))
        return f"{match.group(0)}\n\n{note}" if note else match.group(0)

    changed = 0
    for path in sorted(root.glob("*.md")):
        text = path.read_text(encoding="utf-8")
        new_text = HEADING.sub(repl, text)
        if new_text != text:
            path.write_text(new_text, encoding="utf-8")
            changed += 1

    print(
        f"add_edit_metadata: {len(metadata)} items with git history "
        f"({'linked to ' + remote[0] if remote else 'no recognized remote, hash unlinked'}), "
        f"updated {changed} files"
    )


if __name__ == "__main__":
    main()
