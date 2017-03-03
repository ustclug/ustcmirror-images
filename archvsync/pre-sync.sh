#!/bin/bash

export LOG_ROTATE_CYCLE=0
export LOG="$LOGFILE"
mkdir -p "$BASEDIR/etc"
touch "$BASEDIR/etc/ftpsync-$REPO.conf"
