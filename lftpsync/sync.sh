#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#BIND_ADDRESS=

#LFTPSYNC_HOST=
#LFTPSYNC_PATH=
#LFTPSYNC_EXCLUDE=
#LFTPSYNC_JOBS=

set -e
[[ $DEBUG = true ]] && set -x

LFTPSYNC_JOBS="${LFTPSYNC_JOBS:-$(getconf _NPROCESSORS_ONLN)}"
LFTPSYNC_EXCLUDE+=' -X .~tmp~/'

exec lftp -e "
set net:socket-bind-ipv4 $BIND_ADDRESS
open $LFTPSYNC_HOST
mirror --verbose --skip-noaccess -aec --parallel=$LFTPSYNC_JOBS $LFTPSYNC_EXCLUDE $LFTPSYNC_PATH $TO
bye"
