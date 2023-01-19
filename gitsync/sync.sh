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
#GITSYNC_MIRROR=

is_empty() {
    [[ -z $(ls -A "$1" 2>/dev/null) ]]
}

set -eu
[[ $DEBUG = true ]] && set -x

GITSYNC_REMOTE="${GITSYNC_REMOTE:-origin}"
GITSYNC_BRANCH="${GITSYNC_BRANCH:-master:master}"
GITSYNC_BITMAP="${GITSYNC_BITMAP:-false}"
GITSYNC_MIRROR="${GITSYNC_MIRROR:-false}"

is_empty "$TO" && git clone -v --progress --bare "$GITSYNC_URL" "$TO"

cd "$TO" || exit 1
if [[ $GITSYNC_MIRROR = true ]]; then
    # By default when cloned with --mirror,
    # remote.origin.fetch is set to '+refs/*:refs/*'
    # But refs/pull will also be fetched, which is not needed. Thus we are not using --mirror option and set $GITSYNC_BRANCH manually
    # Tags will be fetched by --tags
    # User-provided GITSYNC_BRANCH is ignored here, as all branches (refs/heads/) are mirrored
    GITSYNC_BRANCH='+refs/heads/*:refs/heads/*'
fi

git fetch "$GITSYNC_REMOTE" "$GITSYNC_BRANCH" -v --progress --tags
git update-server-info

if [[ $GITSYNC_BITMAP = true ]]; then
    git repack -abd
    git gc --auto
fi
