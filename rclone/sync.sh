#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#BIND_ADDRESS=
#RCLONE_DELETE_AFTER=true
#RCLONE_DELETE_EXCLUDED=true

set -eu

RCLONE_EXTRA=${RCLONE_EXTRA:-}

if [[ -n $BIND_ADDRESS ]]; then
    export RCLONE_BIND="$BIND_ADDRESS"
fi

if [[ $DEBUG = true ]]; then
    export RCLONE_VERBOSE=${RCLONE_VERBOSE:-1}
    env | grep '^RCLONE'
    set -x
fi

exec rclone sync $RCLONE_EXTRA "remote:$RCLONE_PATH" "$TO"
