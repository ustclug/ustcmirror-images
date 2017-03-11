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

if [[ ! -x /sync.sh ]]; then
    log '/sync.sh not found'
    exit 1
fi

[[ $DEBUG = true ]] && set -x

export OWNER="${OWNER:-0:0}"
export LOG_ROTATE_CYCLE="${LOG_ROTATE_CYCLE:-0}"
export TO=/data LOGDIR=/log
export LOGFILE="$LOGDIR/result.log"

[[ -f /pre-sync.sh ]] && . /pre-sync.sh

if [[ $LOG_ROTATE_CYCLE -ne 0 ]]; then
    trap 'rotate_log' EXIT
    date '+============ Begin at %F %T ============' | su-exec "$OWNER" tee -a "$LOGFILE"
    su-exec "$OWNER" /sync.sh &> >(tee -a "$LOGFILE") &
else
    LOGFILE='/dev/null'
    date '+============ Begin at %F %T ============'
    su-exec "$OWNER" /sync.sh &
fi

pid="$!"
trap 'killer $pid' INT HUP TERM
wait "$pid"
RETCODE="$?"
date '+============ Finish at %F %T ============' | tee -a "$LOGFILE"

[[ -f /post-sync.sh ]] && . /post-sync.sh

exit $RETCODE
