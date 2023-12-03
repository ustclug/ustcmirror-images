#!/bin/sh

[ "$DEBUG" = "true" ] && set -x

exec python3 /usr/local/lib/tunasync/github-release.py --working-dir "$TO"
