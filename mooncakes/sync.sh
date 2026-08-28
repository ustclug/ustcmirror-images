#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#MOONCAKES_INDEX_URL=
#MOONCAKES_INDEX_DIR=
#MOONCAKES_DOWNLOAD_DIR=
#MOONCAKES_BUCKET=
#MOONCAKES_REGION=
#MOONCAKES_RCLONE_EXTRA=

set -eu
[[ $DEBUG = true ]] && set -x

MOONCAKES_INDEX_URL="${MOONCAKES_INDEX_URL:-https://mooncakes.io/git/index}"
MOONCAKES_INDEX_DIR="${MOONCAKES_INDEX_DIR:-index}"
MOONCAKES_DOWNLOAD_DIR="${MOONCAKES_DOWNLOAD_DIR:-download}"
MOONCAKES_BUCKET="${MOONCAKES_BUCKET:-moonbitlang-mooncakes}"
MOONCAKES_REGION="${MOONCAKES_REGION:-us-west-2}"
MOONCAKES_RCLONE_EXTRA="${MOONCAKES_RCLONE_EXTRA:-}"

export RCLONE_TRANSFERS="${RCLONE_TRANSFERS:-$(getconf _NPROCESSORS_ONLN)}"
export RCLONE_CHECKERS="${RCLONE_CHECKERS:-$(getconf _NPROCESSORS_ONLN)}"

export RCLONE_CONFIG_MOONCAKES_TYPE="${RCLONE_CONFIG_MOONCAKES_TYPE:-s3}"
export RCLONE_CONFIG_MOONCAKES_PROVIDER="${RCLONE_CONFIG_MOONCAKES_PROVIDER:-AWS}"
export RCLONE_CONFIG_MOONCAKES_ENV_AUTH="${RCLONE_CONFIG_MOONCAKES_ENV_AUTH:-false}"
export RCLONE_CONFIG_MOONCAKES_REGION="${RCLONE_CONFIG_MOONCAKES_REGION:-$MOONCAKES_REGION}"
export RCLONE_CONFIG_MOONCAKES_NO_CHECK_BUCKET="${RCLONE_CONFIG_MOONCAKES_NO_CHECK_BUCKET:-true}"

sync_index() {
    local index_dir="$TO/$MOONCAKES_INDEX_DIR"

    if [[ ! -d $index_dir || -z $(ls -A "$index_dir" 2>/dev/null) ]]; then
        rm -rf "$index_dir"
        git clone --bare "$MOONCAKES_INDEX_URL" "$index_dir"
    fi

    cd "$index_dir"
    git remote set-url origin "$MOONCAKES_INDEX_URL"
    git remote prune origin
    git fetch origin '+refs/heads/*:refs/heads/*' --tags --force --prune
    git repack -abd
    git update-server-info
}

sync_downloads() {
    local download_dir="$TO/$MOONCAKES_DOWNLOAD_DIR"

    mkdir -p "$download_dir"
    rclone sync $MOONCAKES_RCLONE_EXTRA "mooncakes:$MOONCAKES_BUCKET" "$download_dir"
}

sync_index
sync_downloads
