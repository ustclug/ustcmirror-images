#!/bin/bash
set -euo pipefail
[[ $DEBUG = true ]] && set -x

python3 /usr/local/lib/tunasync/github-release.py --working-dir "$TO"
