#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#PREFER_IPV6=
#BIND_ADDRESS=

#LFTPSYNC_HOST=
#LFTPSYNC_PATH=
#LFTPSYNC_EXCLUDE=
#LFTPSYNC_JOBS=

set -e
[[ $DEBUG = true ]] && set -x

LFTPSYNC_JOBS="${LFTPSYNC_JOBS:-$(getconf _NPROCESSORS_ONLN)}"
LFTPSYNC_EXCLUDE+=' -X .~tmp~/'

commands='set cmd:fail-exit true;'

if [[ -n $BIND_ADDRESS ]]; then
    if [[ $PREFER_IPV6 = true ]]; then
        commands+="set net:socket-bind-ipv6 $BIND_ADDRESS;"
    else
        commands+="set net:socket-bind-ipv4 $BIND_ADDRESS;"
    fi
fi

commands+="open $LFTPSYNC_HOST;"
commands+="mirror --verbose --use-cache --skip-noaccess -aec --parallel=$LFTPSYNC_JOBS $LFTPSYNC_EXCLUDE $LFTPSYNC_PATH $TO"

exec lftp -c "$commands"
