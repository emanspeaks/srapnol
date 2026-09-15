"""Shared git-history helpers for the docs edit-metadata tooling.

Used by tools/add_edit_metadata.py (per-item, published Doorstop tree) and
tools/mkdocs_hooks.py (per-page, narrative documents in docs/). See docs/README.md.
"""

import re
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# git@host:owner/repo.git (SCP-like), or scheme://[user@]host/owner/repo[.git]
_REMOTE_SCP = re.compile(r"^[\w.-]+@([\w.-]+):(.+?)(?:\.git)?/?$")
_REMOTE_URL = re.compile(r"^(?:https?|ssh)://(?:[^@/]+@)?([^/]+)/(.+?)(?:\.git)?/?$")


def origin_remote() -> str | None:
    result = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def parse_remote(url: str) -> tuple[str, str] | None:
    """(host, "owner/repo") from a git remote URL, or None if unrecognized."""
    match = _REMOTE_SCP.match(url) or _REMOTE_URL.match(url)
    return (match.group(1), match.group(2)) if match else None


def commit_url(host: str, repo_path: str, commit_hash: str) -> str:
    # GitLab (gitlab.com or self-hosted) uses a "-/" separator before "commit"; GitHub
    # and Gitea/Forgejo (Codeberg included) use the same "/commit/<hash>" shape.
    sep = "-/commit" if "gitlab" in host else "commit"
    return f"https://{host}/{repo_path}/{sep}/{commit_hash}"


def resolve_remote() -> tuple[str, str] | None:
    url = origin_remote()
    return parse_remote(url) if url else None


def last_change(path: Path, remote: tuple[str, str] | None) -> str | None:
    """"*Last changed: YYYY-MM-DD by Author (hash)*", or None with no git history."""
    result = subprocess.run(
        ["git", "log", "-1", "--format=%ad%x09%an%x09%h", "--date=short", "--", str(path)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    line = result.stdout.strip()
    if not line:
        return None
    date, author, short_hash = line.split("\t", 2)
    if remote:
        host, repo_path = remote
        hash_text = f"[{short_hash}]({commit_url(host, repo_path, short_hash)})"
    else:
        hash_text = short_hash
    return f"*Last changed: {date} by {author} ({hash_text})*"
