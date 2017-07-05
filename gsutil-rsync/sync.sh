#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#DEBUG=
#GS_URL=

set -eu
[[ $DEBUG = true ]] && set -x

mkdir -p $TO
exec gsutil -m rsync -d -r $GS_URL $TO
