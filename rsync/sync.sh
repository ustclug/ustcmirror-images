#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#BIND_ADDRESS=

#RSYNC_USER=
#RSYNC_HOST=
#RSYNC_PASSWORD=
#RSYNC_PATH=
#RSYNC_BW=
#RSYNC_EXCLUDE=
#RSYNC_MAXDELETE=
#RSYNC_TIMEOUT=
#RSYNC_BLKSIZE=
#RSYNC_EXTRA=
#RSYNC_REMOTE_SHELL=
#RSYNC_DELAY_UPDATES=

set -e
[[ $DEBUG = true ]] && set -x

RSYNC_BW=${RSYNC_BW:-0}
RSYNC_BLKSIZE="${RSYNC_BLKSIZE:-8192}"
RSYNC_TIMEOUT="${RSYNC_TIMEOUT:-14400}"
RSYNC_MAXDELETE=${RSYNC_MAXDELETE:-4000}
RSYNC_SPARSE="${RSYNC_SPARSE:-true}"
RSYNC_DELAY_UPDATES="${RSYNC_DELAY_UPDATES:-true}"

opts="-pPrltvH --partial-dir=.rsync-partial --timeout ${RSYNC_TIMEOUT} --safe-links --delete-delay --delete-excluded"

[[ -n $RSYNC_USER ]] && RSYNC_HOST="$RSYNC_USER@$RSYNC_HOST"

[[ $RSYNC_DELAY_UPDATES = true ]] && opts+=' --delay-updates'
[[ $RSYNC_SPARSE = true ]] && opts+=' --sparse'
[[ $RSYNC_BLKSIZE -ne 0 ]] && opts+=" --block-size ${RSYNC_BLKSIZE}"
RSYNC_EXCLUDE+=' --exclude .~tmp~/'
if [[ -n $BIND_ADDRESS ]]; then
    if [[ $BIND_ADDRESS =~ .*: ]]; then
        opts+=" -6 --address $BIND_ADDRESS"
    else
        opts+=" -4 --address $BIND_ADDRESS"
    fi
fi

if [[ -n $RSYNC_REMOTE_SHELL ]]; then
    exec rsync $RSYNC_EXCLUDE --bwlimit "$RSYNC_BW" --max-delete "$RSYNC_MAXDELETE" -e "$RSYNC_REMOTE_SHELL" $opts $RSYNC_EXTRA "$RSYNC_HOST:$RSYNC_PATH" "$TO"
else
    exec rsync $RSYNC_EXCLUDE --bwlimit "$RSYNC_BW" --max-delete "$RSYNC_MAXDELETE" $opts $RSYNC_EXTRA "$RSYNC_HOST::$RSYNC_PATH" "$TO"
fi
