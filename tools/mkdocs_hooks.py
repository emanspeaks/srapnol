"""MkDocs build hook: adds per-page last-changed-by/when metadata from git.

Runs on every page MkDocs actually renders -- docs/README.md and the narrative
documents (SDP.md, compliance-matrix.md, etc.). The Doorstop item sources under
docs/{sys,srs,des,tst} are excluded from the site by mkdocs.yml `exclude_docs`, and
docs/build/req/*.md (the *published* tree, which already carries its own per-item
metadata from tools/add_edit_metadata.py) is git-ignored, so git has no history for it
and this hook silently contributes nothing there. See docs/README.md.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from git_metadata import REPO_ROOT, last_change, resolve_remote  # noqa: E402

_remote = resolve_remote()


def on_page_markdown(markdown, page, config, files):
    src_path = Path(page.file.src_path.replace("\\", "/"))
    if src_path.parts and src_path.parts[0] == "build":
        return markdown  # generated, not a committed source document

    note = last_change(REPO_ROOT / "docs" / src_path, _remote)
    if not note:
        return markdown

    lines = markdown.splitlines()
    for i, line in enumerate(lines):
        if line.startswith("# "):
            return "\n".join(lines[: i + 1] + ["", note] + lines[i + 1 :])
    return f"{note}\n\n{markdown}"
