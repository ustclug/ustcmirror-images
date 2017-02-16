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
#RSYNC_OPTIONS=
#RSYNC_EXCLUDE=
#RSYNC_MAXDELETE=

set -e
[[ $DEBUG = true ]] && set -x

[[ -n $RSYNC_USER ]] && RSYNC_HOST="$RSYNC_USER@$RSYNC_HOST"

RSYNC_BW=${RSYNC_BW:-0}
RSYNC_MAXDELETE=${RSYNC_MAXDELETE:-4000}
RSYNC_OPTIONS=${RSYNC_OPTIONS:-'-4pPrltvHSB8192 --partial-dir=.rsync-partial --timeout 14400 --delay-updates --safe-links --delete-delay --delete-excluded'}
RSYNC_EXCLUDE+=' --exclude .~tmp~/'

exec rsync $RSYNC_EXCLUDE --bwlimit "$RSYNC_BW" --max-delete "$RSYNC_MAXDELETE" --address "$BIND_ADDRESS" $RSYNC_OPTIONS "$RSYNC_HOST::$RSYNC_PATH" "$TO"
