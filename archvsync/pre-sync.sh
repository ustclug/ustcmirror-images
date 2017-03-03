#!/bin/bash

# override the `killer` func in entry.sh
killer() {
    kill -- "$1"
    pkill rsync
    wait "$1"
}

export LOG_ROTATE_CYCLE=0
export LOG="$LOGFILE"
mkdir -p "$BASEDIR/etc"
touch "$BASEDIR/etc/ftpsync-$REPO.conf"
