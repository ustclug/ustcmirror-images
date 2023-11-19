#!/bin/bash

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

export DEBUG="${DEBUG:-false}"
[[ $DEBUG = true ]] && set -x
set -u

export SYNC_SCRIPT=${SYNC_SCRIPT:-"/sync.sh"}
export PRE_SYNC_SCRIPT=${PRE_SYNC_SCRIPT:-"/pre-sync.sh"}
export POST_SYNC_SCRIPT=${POST_SYNC_SCRIPT:-"/post-sync.sh"}
export OWNER="${OWNER:-0:0}"
export LOG_ROTATE_CYCLE="${LOG_ROTATE_CYCLE:-0}"
export TO="${TO:-/data/}"
export LOGDIR="${LOGDIR:-/log/}"
export LOGFILE="$LOGDIR/result.log"
declare -i RETRY
export RETRY="${RETRY:-0}"

main() {
    local abort ret

    if [[ ! -x $SYNC_SCRIPT ]]; then
        log "$SYNC_SCRIPT not found"
        return 1
    fi

    chown "$OWNER" "$TO" # not recursive

    [[ -f $PRE_SYNC_SCRIPT ]] && . "$PRE_SYNC_SCRIPT"

    date '+============ SYNC STARTED AT %F %T ============'

    abort=0
    while [[ $RETRY -ge 0 ]] && [[ $abort -eq 0 ]]; do
        log "*********** 8< ***********"
        su-exec "$OWNER" "$SYNC_SCRIPT" &
        pid="$!"
        trap 'killer $pid; abort=1; log Aborted' INT HUP TERM
        wait "$pid"
        ret="$?"
        [[ $ret -eq 0 ]] && break
        RETRY=$((RETRY-1))
    done

    date '+============ SYNC FINISHED AT %F %T ============'

    [[ -f $POST_SYNC_SCRIPT ]] && . "$POST_SYNC_SCRIPT"

    return $ret
}

if [[ $LOG_ROTATE_CYCLE -ne 0 ]]; then
    trap 'rotate_log' EXIT
    touch "$LOGFILE" && chown "$OWNER" "$LOGFILE"
else
    LOGFILE='/dev/null'
fi

main &> >(tee -a "$LOGFILE")
