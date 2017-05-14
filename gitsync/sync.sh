#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#GITSYNC_URL=
#GITSYNC_BRANCH=
#GITSYNC_REMOTE=
#GITSYNC_BITMAP=

is_empty() {
    [[ -z $(ls -A "$1" 2>/dev/null) ]]
}

set -eu
[[ $DEBUG = true ]] && set -x

GITSYNC_REMOTE="${GITSYNC_REMOTE:-origin}"
GITSYNC_BRANCH="${GITSYNC_BRANCH:-master:master}"
GITSYNC_BITMAP="${GITSYNC_BITMAP:-false}"

is_empty "$TO" && git clone -v --progress --bare "$GITSYNC_URL" "$TO"

cd "$TO" || exit 1
git fetch "$GITSYNC_REMOTE" "$GITSYNC_BRANCH" -v --progress --tags
git update-server-info

if [[ $GITSYNC_BITMAP = true ]]; then
    git repack -abd
    git gc --auto
fi
