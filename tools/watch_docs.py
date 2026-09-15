"""Watch the Doorstop source trees and republish on change.

`mkdocs serve` live-reloads on changes to docs/build/req/*.md (the published tree)
but has no idea docs/{sys,srs,des,tst}/*.md even exist as sources -- editing or
committing an item there does nothing to the served site until the publish pipeline
(doorstop publish, tools/fix_anchors.py, tools/add_edit_metadata.py) reruns. This
polls those source trees and reruns the pipeline whenever a file changes.

`pixi run docs-serve` (tools/serve_docs.py) already runs this as a background thread
alongside `mkdocs serve`; run this file directly only to republish continuously
without also serving (e.g. to keep docs/build/req fresh for some other purpose).

Usage: python tools/watch_docs.py [--interval SECONDS]
"""

import argparse
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
WATCH_DIRS = ["sys", "srs", "des", "tst"]
PIPELINE = [
    ["doorstop", "publish", "all", "docs/build/req", "--markdown"],
    [sys.executable, "tools/fix_anchors.py", "docs/build/req"],
    [sys.executable, "tools/add_edit_metadata.py", "docs/build/req"],
]


def snapshot() -> dict[Path, float]:
    state = {}
    for sub in WATCH_DIRS:
        for path in (REPO_ROOT / "docs" / sub).glob("*.md"):
            state[path] = path.stat().st_mtime
    return state


def republish() -> None:
    for cmd in PIPELINE:
        subprocess.run(cmd, cwd=REPO_ROOT, check=True)


def watch_loop(interval: float) -> None:
    """Poll forever; rerun `republish()` whenever a source file changes."""
    last = snapshot()
    while True:
        time.sleep(interval)
        current = snapshot()
        if current != last:
            last = current
            print("watch_docs: change detected, republishing...", flush=True)
            try:
                republish()
            except subprocess.CalledProcessError as exc:
                print(f"watch_docs: republish failed: {exc}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--interval", type=float, default=1.0)
    args = parser.parse_args()

    print(
        f"watch_docs: polling docs/{{{','.join(WATCH_DIRS)}}} every "
        f"{args.interval}s (Ctrl+C to stop)",
        flush=True,
    )
    republish()
    print("watch_docs: initial publish done", flush=True)
    try:
        watch_loop(args.interval)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
