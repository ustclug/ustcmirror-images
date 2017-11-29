#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#DEBUG=
#GS_URL=
#GS_EXTRA=
#GS_EXCLUDE=

GS_EXTRA="${GS_EXTRA:-}"
GS_EXCLUDE="${GS_EXCLUDE:-}"

set -eu
if [[ $DEBUG = true ]]; then
    GS_EXTRA+=" -D"
    set -x
fi

exec gsutil -m $GS_EXTRA rsync -C -d -r -U $GS_EXCLUDE "$GS_URL" "$TO"
