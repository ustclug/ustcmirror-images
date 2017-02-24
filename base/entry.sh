#!/bin/bash
log() {
    echo "$@" >&2
}

killer() {
    if [[ -n $GITSYNC_URL ]]; then
        pkill git
    else
        # exec rsync/lftp in /sync.sh
        kill -- "$1"
    fi
    wait "$1"
}

rotate_log() {
    su-exec "$OWNER" savelog -c "$ROTATE_CYCLE" "$LOGFILE"
}

if [[ ! -x /sync.sh ]]; then
    log '/sync.sh not found'
    exit 1
fi

[[ $DEBUG = true ]] && set -x

[[ -z $OWNER ]] && export OWNER='0:0' # root:root

[[ -x /pre-sync.sh ]] && . /pre-sync.sh

export TO=/data LOGDIR=/log
export LOGFILE="$LOGDIR/result.log"

if [[ $AUTO_ROTATE_LOG = true ]]; then
    trap 'rotate_log' EXIT
    su-exec "$OWNER" touch "$LOGFILE"
    su-exec "$OWNER" /sync.sh &> >(tee -a "$LOGFILE") &
else
    su-exec "$OWNER" /sync.sh &
fi
pid="$!"
trap 'killer $pid' INT HUP TERM
wait "$pid"

[[ -x /post-sync.sh ]] && . /post-sync.sh

exit 0
