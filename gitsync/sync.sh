#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=

## SET IN ENVIRONMENT VARIABLES
#GITSYNC_URL=
#GITSYNC_BRANCH=
#GITSYNC_REMOTE=
#GITSYNC_BITMAP=

is_empty() {
    [[ -z $(ls -A "$1" 2>/dev/null) ]]
}

set -e
[[ $DEBUG = true ]] && set -x

GITSYNC_REMOTE="${GITSYNC_REMOTE:-origin}"
GITSYNC_BRANCH="${GITSYNC_BRANCH:-master:master}"
GITSYNC_BITMAP="${GITSYNC_BITMAP:-false}"

is_empty "$TO" && git clone -v --progress --bare "$GITSYNC_URL" "$TO"

cd "$TO" || exit 1
git fetch "$GITSYNC_REMOTE" "$GITSYNC_BRANCH" -v --progress
git update-server-info

if [[ -z $DEBUG || $DEBUG = false ]]; then
    git gc --auto
    [[ $GITSYNC_BITMAP = true ]] && git repack -abd
fi
