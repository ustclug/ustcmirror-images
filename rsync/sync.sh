#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

set -eu
[[ $DEBUG = true ]] && set -x

BIND_ADDRESS=${BIND_ADDRESS:-''}

RSYNC_USER=${RSYNC_USER:-''}
RSYNC_BW=${RSYNC_BW:-0}
RSYNC_EXCLUDE=${RSYNC_EXCLUDE:-' --exclude .~tmp~/'}
RSYNC_FILTER=${RSYNC_FILTER:-}
RSYNC_MAXDELETE=${RSYNC_MAXDELETE:-4000}
RSYNC_TIMEOUT="${RSYNC_TIMEOUT:-14400}"
RSYNC_BLKSIZE="${RSYNC_BLKSIZE:-8192}"
RSYNC_EXTRA=${RSYNC_EXTRA:-''}
RSYNC_RSH=${RSYNC_RSH:-''}
RSYNC_DELAY_UPDATES="${RSYNC_DELAY_UPDATES:-true}"
RSYNC_SPARSE="${RSYNC_SPARSE:-true}"
RSYNC_DELETE_DELAY="${RSYNC_DELETE_DELAY:-true}"
RSYNC_DELETE_EXCLUDED="${RSYNC_DELETE_EXCLUDED:-true}"
RSYNC_NO_DELETE="${RSYNC_NO_DELETE:-false}"
RSYNC_SSL="${RSYNC_SSL:-false}"

opts="-pPrltvH --partial-dir=.rsync-partial --timeout ${RSYNC_TIMEOUT} --safe-links"

[[ -n $RSYNC_USER ]] && RSYNC_HOST="$RSYNC_USER@$RSYNC_HOST"

if [[ $RSYNC_NO_DELETE != true ]]; then
  [[ $RSYNC_DELETE_EXCLUDED = true ]] && opts+=' --delete-excluded'
  [[ $RSYNC_DELETE_DELAY = true ]] && opts+=' --delete-delay' || opts+=' --delete'
fi
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

filter_file=/tmp/rsync-filter.txt
echo '- .~tmp~/' > "$filter_file"
if [ -n "$RSYNC_FILTER" ]; then
  echo "$RSYNC_FILTER" >> "$filter_file"
fi

if [[ -n $RSYNC_RSH ]]; then
  RSYNC_URL="$RSYNC_HOST:$RSYNC_PATH"
else
  RSYNC_URL="rsync://$RSYNC_HOST/$RSYNC_PATH"
fi

max_delete_arg="--max-delete $RSYNC_MAXDELETE"
[[ $RSYNC_NO_DELETE = true ]] && max_delete_arg=''

rsync_program="rsync"
if [[ $RSYNC_SSL = true ]]; then
  rsync_program="rsync-ssl"
fi

exec $rsync_program $RSYNC_EXCLUDE --filter="merge $filter_file" --bwlimit "$RSYNC_BW" $max_delete_arg $opts $RSYNC_EXTRA "$RSYNC_URL" "$TO"
