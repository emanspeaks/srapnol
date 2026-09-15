"""Insert last-changed-by/when metadata into published Doorstop items from git.

Doorstop tracks no per-item author or date -- only a content fingerprint. This adds
a "*Last changed: YYYY-MM-DD by Author*" line under each item's heading, read from
the git history of that item's own source file (docs/sys/UID.md etc.), the only
place this project actually records who changed a requirement and when. An item
never committed gets no line -- git has no history for it yet.

Usage: python tools/add_edit_metadata.py <published-dir>
"""

import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIRS = ["sys", "srs", "des", "tst"]
HEADING = re.compile(r"^(#{1,6} .*\{#([\w-]+)\})\s*$", re.MULTILINE)


def last_change(path: Path) -> str | None:
    """"YYYY-MM-DD by Author", from the last commit touching `path`, or None."""
    result = subprocess.run(
        ["git", "log", "-1", "--format=%ad%x09%an", "--date=short", "--", str(path)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    line = result.stdout.strip()
    if not line:
        return None
    date, author = line.split("\t", 1)
    return f"*Last changed: {date} by {author}*"


def main() -> None:
    root = Path(sys.argv[1])
    metadata: dict[str, str] = {}
    for sub in SOURCE_DIRS:
        for path in sorted((REPO_ROOT / "docs" / sub).glob("*.md")):
            note = last_change(path)
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
        f"add_edit_metadata: {len(metadata)} items with git history, "
        f"updated {changed} files"
    )


if __name__ == "__main__":
    main()
