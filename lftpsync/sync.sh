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

LFTPSYNC_MAX_JOBS=32  # count of processors on mirrors2

is_ipv6() {
    # string contains a colon
    [[ $1 =~ .*: ]]
}

set -eu
[[ $DEBUG = true ]] && set -x

LFTPSYNC_PATH=${LFTPSYNC_PATH:-}
LFTPSYNC_JOBS="${LFTPSYNC_JOBS:-$(getconf _NPROCESSORS_ONLN)}"
LFTPSYNC_EXCLUDE="${LFTPSYNC_EXCLUDE:- -X .~tmp~/}"
BIND_ADDRESS="${BIND_ADDRESS:-}"

if [ "$LFTPSYNC_JOBS" -gt "$LFTPSYNC_MAX_JOBS" ]; then
    LFTPSYNC_JOBS=$LFTPSYNC_MAX_JOBS
fi

commands='set cmd:fail-exit true;'

if [[ -n $BIND_ADDRESS ]]; then
    if is_ipv6 "$BIND_ADDRESS"; then
        commands+="set net:socket-bind-ipv6 $BIND_ADDRESS;"
    else
        commands+="set net:socket-bind-ipv4 $BIND_ADDRESS;"
    fi
fi

commands+="open $LFTPSYNC_HOST;"
commands+="lcd $TO;"
commands+="mirror --verbose --use-cache -aec --parallel=$LFTPSYNC_JOBS $LFTPSYNC_EXCLUDE"

if [[ -n $LFTPSYNC_PATH ]]; then
    commands+=" $LFTPSYNC_PATH"
fi

exec lftp -c "$commands"
