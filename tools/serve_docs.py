"""`mkdocs serve` plus a live watcher for the Doorstop source trees.

`mkdocs serve` alone only live-reloads on changes to the *published* tree
(docs/build/req/*.md); it has no idea docs/{sys,srs,des,tst}/*.md exist as sources.
This runs tools/watch_docs.py's poll-and-republish loop as a background daemon thread
in the same process as `mkdocs serve`, so editing or committing a Doorstop item shows
up in the served site without a second terminal, and stopping this (Ctrl+C) stops the
watcher too -- there is no separate process left running to remember to kill.

Usage: python tools/serve_docs.py [--interval SECONDS] [--dev-addr HOST:PORT]
"""

import argparse
import subprocess
import sys
import threading
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from watch_docs import WATCH_DIRS, republish, watch_loop  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--interval", type=float, default=1.0)
    parser.add_argument("--dev-addr", default="127.0.0.1:3000")
    args = parser.parse_args()

    republish()
    print("serve_docs: initial publish done", flush=True)

    watcher = threading.Thread(target=watch_loop, args=(args.interval,), daemon=True)
    watcher.start()
    print(
        f"serve_docs: watching docs/{{{','.join(WATCH_DIRS)}}} every "
        f"{args.interval}s for changes",
        flush=True,
    )

    try:
        subprocess.run(
            ["mkdocs", "serve", "--dev-addr", args.dev_addr], cwd=REPO_ROOT
        )
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
