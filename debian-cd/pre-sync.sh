#!/bin/bash

# override the `killer` func in entry.sh
killer() {
    kill -- "$1"
    pkill rsync
    wait "$1"
}

IGNORE_LOCK="${IGNORE_LOCK:-false}"
if [[ $IGNORE_LOCK = true ]]; then
    rm -f "$TO"/Archive-Update-*
fi

DELETEFIRST=${DELETEFIRST:-0}
EXCLUDE=${EXCLUDE:-}

cat > /etc/debian-cd-mirror.conf <<EOF
RSYNC_HOST=$RSYNC_HOST
RSYNC_MODULE=$RSYNC_MODULE
RSYNC_PASSWORD=$RSYNC_PASSWORD
RSYNC_USER=$RSYNC_USER
TO=/data/
ERRORMAIL=root
MIRRORNAME=$MIRRORNAME
DELETEFIRST=$DELETEFIRST
EXCLUDE=$EXCLUDE
HUB=false
tmpDirBase=/tmp/
LOGDIR=$LOGDIR
jigdoConf=/etc/jigdo/jigdo-mirror.conf
masterList=\$tmpDirBase/master.list
EOF

chown -R "$OWNER" /etc/jigdo/
