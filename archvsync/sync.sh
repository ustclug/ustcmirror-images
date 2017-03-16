#!/bin/bash

#REPO=

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#DEBUG=
#BIND_ADDRESS=

set -e
[[ $DEBUG = true ]] && set -x

export LOG="$LOGFILE"
if [[ -n $BIND_ADDRESS ]]; then
    if [[ $BIND_ADDRESS =~ .*: ]]; then
        RSYNC_EXTRA+=" -6 --address $BIND_ADDRESS"
    else
        RSYNC_EXTRA+=" -4 --address $BIND_ADDRESS"
    fi
    export RSYNC_EXTRA
fi

exec ftpsync "sync:archive:$REPO"
