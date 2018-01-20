#!/bin/bash

export SYNC_SCRIPT=${SYNC_SCRIPT:-"/sync.sh"}
export PRE_SYNC_SCRIPT=${PRE_SYNC_SCRIPT:-"/pre-sync.sh"}
export POST_SYNC_SCRIPT=${POST_SYNC_SCRIPT:-"/post-sync.sh"}

log() {
    echo "$@" >&2
}

killer() {
    kill -- "$1"
    wait "$1"
}

rotate_log() {
    su-exec "$OWNER" savelog -c "$LOG_ROTATE_CYCLE" "$LOGFILE"
}

if [[ ! -x $SYNC_SCRIPT ]]; then
    log "$SYNC_SCRIPT not found"
    exit 1
fi

declare -ix RETRY
export DEBUG="${DEBUG:-false}"
[[ $DEBUG = true ]] && set -x
set -u

export OWNER="${OWNER:-0:0}"
export LOG_ROTATE_CYCLE="${LOG_ROTATE_CYCLE:-0}"
export TO=/data/ LOGDIR=/log/
export LOGFILE="$LOGDIR/result.log"
export RETRY="${RETRY:-0}"

main() {
    local abort ret

    chown "$OWNER" "$TO" # not recursive

    [[ -f $PRE_SYNC_SCRIPT ]] && . "$PRE_SYNC_SCRIPT"

    if [[ $LOG_ROTATE_CYCLE -ne 0 ]]; then
        trap 'rotate_log' EXIT
    else
        LOGFILE='/dev/null'
    fi

    date '+============ SYNC STARTED AT %F %T ============' | su-exec "$OWNER" tee -a "$LOGFILE"

    abort=0
    while [[ $RETRY -ge 0 ]] && [[ $abort -eq 0 ]]; do
        log "*********** 8< ***********"
        su-exec "$OWNER" "$SYNC_SCRIPT" &> >(tee -a "$LOGFILE") &
        pid="$!"
        trap 'killer $pid; abort=1; log Aborted' INT HUP TERM
        wait "$pid"
        ret="$?"
        RETRY=$((RETRY-1))
    done

    date '+============ SYNC FINISHED AT %F %T ============' | tee -a "$LOGFILE"

    [[ -f $POST_SYNC_SCRIPT ]] && . "$POST_SYNC_SCRIPT"

    return $ret
}

main
