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
#GITSYNC_CHECKOUT=
#GITSYNC_TREELESS=
#GITSYNC_GEOMETRIC=
#GITSYNC_MAINTENANCE_INTERVAL_SECONDS=

is_empty() {
    [[ -z $(ls -A "$1" 2>/dev/null) ]]
}

set -eu
[[ $DEBUG = true ]] && set -x

GITSYNC_REMOTE="${GITSYNC_REMOTE:-origin}"
GITSYNC_BRANCH="${GITSYNC_BRANCH:-master:master}"
GITSYNC_BITMAP="${GITSYNC_BITMAP:-false}"
GITSYNC_MIRROR="${GITSYNC_MIRROR:-false}"
GITSYNC_CHECKOUT="${GITSYNC_CHECKOUT:-false}"
GITSYNC_TREELESS="${GITSYNC_TREELESS:-false}"
GITSYNC_GEOMETRIC="${GITSYNC_GEOMETRIC:-false}"
GITSYNC_MAINTENANCE_INTERVAL_SECONDS="${GITSYNC_MAINTENANCE_INTERVAL_SECONDS:-604800}"

run_periodic_maintenance() {
    local git_dir stamp now last=0

    if (( GITSYNC_MAINTENANCE_INTERVAL_SECONDS <= 0 )); then
        return
    fi

    git_dir="$(git rev-parse --git-dir)"
    stamp="$git_dir/gitsync-maintenance.stamp"
    now="$(date +%s)"

    if [[ -f $stamp ]]; then
        last="$(stat -c %Y "$stamp" 2>/dev/null || printf '0')"
    fi

    if (( now - last < GITSYNC_MAINTENANCE_INTERVAL_SECONDS )); then
        return
    fi

    git reflog expire \
        --expire=all \
        --expire-unreachable=all \
        --all
    git gc --prune=now --no-cruft
    touch "$stamp"
}

is_empty "$TO" && git clone -v --progress \
    $([ "$GITSYNC_CHECKOUT" = false ] && echo "--bare") \
    $([ "$GITSYNC_CHECKOUT" = true ] && echo "--no-checkout") \
    $([ "$GITSYNC_TREELESS" = true ] && echo "--filter=tree:0") \
    "$GITSYNC_URL" "$TO"

cd "$TO" || exit 1
if [[ $GITSYNC_MIRROR = true ]]; then
    # By default when cloned with --mirror,
    # remote.origin.fetch is set to '+refs/*:refs/*'
    # But refs/pull will also be fetched, which is not needed. Thus we are not using --mirror option and set $GITSYNC_BRANCH manually
    # Tags will be fetched by --tags
    # User-provided GITSYNC_BRANCH is ignored here, as all branches (refs/heads/) are mirrored
    GITSYNC_BRANCH='+refs/heads/*:refs/heads/*'
fi

if [[ $GITSYNC_CHECKOUT = true ]]; then
    git fetch "$GITSYNC_REMOTE" $GITSYNC_BRANCH -u -v --progress --force --prune --prune-tags
    git reset --hard FETCH_HEAD
else
    git fetch "$GITSYNC_REMOTE" $GITSYNC_BRANCH -v --progress --tags --force --prune --prune-tags
fi

run_periodic_maintenance

if [[ $GITSYNC_BITMAP = true ]]; then
    if [[ $GITSYNC_GEOMETRIC = true ]]; then
        git repack --write-midx --write-bitmap-index -d --geometric=2
    else
        git repack -abd
    fi
fi

if [[ $GITSYNC_CHECKOUT = false ]]; then
    git update-server-info
fi
