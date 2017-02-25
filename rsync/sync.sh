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
#RSYNC_EXTRA_OPTS=
#RSYNC_DELAY_UPDATES=

set -e
[[ $DEBUG = true ]] && set -x

RSYNC_BW=${RSYNC_BW:-0}
RSYNC_BLKSIZE="${RSYNC_BLKSIZE:-8192}"
RSYNC_TIMEOUT="${RSYNC_TIMEOUT:-14400}"
RSYNC_MAXDELETE=${RSYNC_MAXDELETE:-4000}
RSYNC_DELAY_UPDATES="${RSYNC_DELAY_UPDATES:-true}"

OPTS="-pPrltvHS --partial-dir=.rsync-partial --timeout ${RSYNC_TIMEOUT} --safe-links --delete-delay --delete-excluded"

[[ -n $RSYNC_USER ]] && RSYNC_HOST="$RSYNC_USER@$RSYNC_HOST"

[[ $RSYNC_DELAY_UPDATES = true ]] && OPTS+=' --delay-updates'
[[ $RSYNC_BLKSIZE -ne 0 ]] && OPTS+=" --block-size ${RSYNC_BLKSIZE}"
RSYNC_EXCLUDE+=' --exclude .~tmp~/'
if [[ -n $BIND_ADDRESS ]]; then
    if [[ $BIND_ADDRESS =~ .*: ]]; then
        OPTS+=" -6 --address $BIND_ADDRESS"
    else
        OPTS+=" -4 --address $BIND_ADDRESS"
    fi
fi

exec rsync $RSYNC_EXCLUDE --bwlimit "$RSYNC_BW" --max-delete "$RSYNC_MAXDELETE" $OPTS $RSYNC_EXTRA_OPTS "$RSYNC_HOST::$RSYNC_PATH" "$TO"
