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
BIND_ADDRESS=${BIND_ADDRESS:-}

export RCLONE_TRANSFERS=${RCLONE_TRANSFERS:-$(getconf _NPROCESSORS_ONLN)}
export RCLONE_CHECKERS=${RCLONE_CHECKERS:-$(getconf _NPROCESSORS_ONLN)}

if [[ -n $BIND_ADDRESS ]]; then
    export RCLONE_BIND="$BIND_ADDRESS"
fi

if [[ $DEBUG = true ]]; then
    export RCLONE_VERBOSE=${RCLONE_VERBOSE:-2}
    export RCLONE_DUMP_FILTERS=true
    env | grep '^RCLONE' | sort -t '=' -k 1
    set -x
fi

exec rclone sync $RCLONE_EXTRA "remote:$RCLONE_PATH" "$TO"
