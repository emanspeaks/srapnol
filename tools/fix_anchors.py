"""Rewrite Doorstop's Markdown anchor links to match `attr_list` ids.

Doorstop's Markdown publisher appends " {#UID}" to every heading, meant for a
renderer's `attr_list` extension to consume as the heading's real id (so the
UID itself is a clean, stable anchor and the "{#UID}" text does not render).
But Doorstop computes its own internal links (the per-document Table of
Contents, and each item's "Parent links:"/"Child links:") by slugifying the
*entire* heading line, "{#UID}" suffix included -- a scheme that only lines
up with a renderer that does *not* honor attr_list. Enabling attr_list (as
mkdocs.yml does, to stop the "{#UID}" suffix from rendering as literal text)
therefore breaks every one of those precomputed links.

This reproduces Doorstop's own slug function on each published heading to
recover the mapping from its old slug to the clean UID, then rewrites every
"(...#old-slug)" link in the published tree to "(...#UID)". Run after
`doorstop publish --markdown` and before the site is built; see
docs/README.md.

Usage: python tools/fix_anchors.py <published-dir>
"""

import re
import sys
from pathlib import Path

HEADING = re.compile(r"^#{1,6} .*\{#([\w-]+)\}\s*$", re.MULTILINE)
LINK = re.compile(r"\(((?:[A-Za-z0-9_-]+\.md)?)#([a-z0-9-]+)\)")


def clean_link(text: str) -> str:
    """Doorstop's own doorstop/core/publishers/markdown.py:clean_link."""
    text = re.sub(r"^#*\s*", "", text)
    text = text.lower()
    text = text.replace(" ", "-")
    text = re.sub("[^a-z0-9-]", "", text)
    return text


def main() -> None:
    root = Path(sys.argv[1])
    files = sorted(root.glob("*.md"))
    texts = {path: path.read_text(encoding="utf-8") for path in files}

    slug_to_uid: dict[str, str] = {}
    for text in texts.values():
        for match in HEADING.finditer(text):
            slug_to_uid[clean_link(match.group(0))] = match.group(1)

    def repl(match: re.Match) -> str:
        doc, slug = match.group(1), match.group(2)
        uid = slug_to_uid.get(slug)
        return f"({doc}#{uid})" if uid else match.group(0)

    changed = 0
    for path, text in texts.items():
        new_text = LINK.sub(repl, text)
        if new_text != text:
            path.write_text(new_text, encoding="utf-8")
            changed += 1

    print(
        f"fix_anchors: {len(slug_to_uid)} headings mapped, "
        f"rewrote links in {changed}/{len(files)} files"
    )


if __name__ == "__main__":
    main()
