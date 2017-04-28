#!/bin/bash

# override the `killer` func in entry.sh
killer() {
    kill -- "$1"
    pkill rsync
    wait "$1"
}

touch "$BASEDIR/etc/ftpsync-$REPO.conf"
IGNORE_LOCK="${IGNORE_LOCK:-false}"
if [[ $IGNORE_LOCK = true ]]; then
    rm -f "$TO"/Archive-Update-*
fi
