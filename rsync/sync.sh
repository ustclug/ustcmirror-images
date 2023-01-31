#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#BIND_ADDRESS=

#RSYNC_PATH=
#RSYNC_HOST=

#RSYNC_USER=
#RSYNC_PASSWORD=
#RSYNC_RSH=
#RSYNC_BW=
#RSYNC_EXCLUDE=
#RSYNC_MAXDELETE=
#RSYNC_TIMEOUT=
#RSYNC_BLKSIZE=
#RSYNC_EXTRA=
#RSYNC_DELAY_UPDATES=
#RSYNC_SPARSE=

set -eu
[[ $DEBUG = true ]] && set -x

BIND_ADDRESS=${BIND_ADDRESS:-''}

RSYNC_USER=${RSYNC_USER:-''}
RSYNC_BW=${RSYNC_BW:-0}
RSYNC_EXCLUDE=${RSYNC_EXCLUDE:-' --exclude .~tmp~/'}
RSYNC_MAXDELETE=${RSYNC_MAXDELETE:-4000}
RSYNC_TIMEOUT="${RSYNC_TIMEOUT:-14400}"
RSYNC_BLKSIZE="${RSYNC_BLKSIZE:-8192}"
RSYNC_EXTRA=${RSYNC_EXTRA:-''}
RSYNC_RSH=${RSYNC_RSH:-''}
RSYNC_DELAY_UPDATES="${RSYNC_DELAY_UPDATES:-true}"
RSYNC_SPARSE="${RSYNC_SPARSE:-true}"
RSYNC_DELETE_DELAY="${RSYNC_DELETE_DELAY:-true}"

opts="-pPrltvH --partial-dir=.rsync-partial --timeout ${RSYNC_TIMEOUT} --safe-links --delete-excluded"

[[ -n $RSYNC_USER ]] && RSYNC_HOST="$RSYNC_USER@$RSYNC_HOST"

[[ $RSYNC_DELETE_DELAY = true ]] && opts+=' --delete-delay' || opts+=' --delete'
[[ $RSYNC_DELAY_UPDATES = true ]] && opts+=' --delay-updates'
[[ $RSYNC_SPARSE = true ]] && opts+=' --sparse'
[[ $RSYNC_BLKSIZE -ne 0 ]] && opts+=" --block-size ${RSYNC_BLKSIZE}"

if [[ -n $BIND_ADDRESS ]]; then
    if [[ $BIND_ADDRESS =~ .*: ]]; then
        opts+=" -6 --address $BIND_ADDRESS"
    else
        opts+=" -4 --address $BIND_ADDRESS"
    fi
fi

if [[ -n $RSYNC_RSH ]]; then
    exec rsync $RSYNC_EXCLUDE --bwlimit "$RSYNC_BW" --max-delete "$RSYNC_MAXDELETE" $opts $RSYNC_EXTRA "$RSYNC_HOST:$RSYNC_PATH" "$TO"
else
    exec rsync $RSYNC_EXCLUDE --bwlimit "$RSYNC_BW" --max-delete "$RSYNC_MAXDELETE" $opts $RSYNC_EXTRA "$RSYNC_HOST::$RSYNC_PATH" "$TO"
fi
