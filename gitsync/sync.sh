#!/bin/bash

## SET IN ENVIRONMENT VARIABLES
#TO=

#GITSYNC_URL=
#GITSYNC_BRANCH=
#GITSYNC_REMOTE=
#GITSYNC_BITMAP=

set -e
[[ $DEBUG = true ]] && set -x

GITSYNC_REMOTE="${GITSYNC_REMOTE:-origin}"
GITSYNC_BRANCH="${GITSYNC_BRANCH:-master:master}"
GITSYNC_BITMAP="${GITSYNC_BITMAP:-false}"

[[ ! -d $TO ]] && git clone --bare "$GITSYNC_URL" "$TO"

cd "$GITSYNC_TO" || exit 1
git fetch "$GITSYNC_REMOTE" "$GITSYNC_BRANCH" -v --progress
git update-server-info

if [[ -z $DEBUG || $DEBUG = false ]]; then
    git gc --auto
    [[ $GITSYNC_BITMAP = true ]] && git repack -abd
fi
