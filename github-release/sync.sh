#!/bin/bash
set -euo pipefail
[[ $DEBUG = true ]] && set -x

WORKERS=8 # Number of concurrent downloading jobs

python3 /usr/local/lib/tunasync/github-release.py --working-dir "$TO" --workers $WORKERS
