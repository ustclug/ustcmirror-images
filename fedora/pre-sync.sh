#!/bin/bash

_CONF_FILE='/etc/quick-fedora-mirror.conf'

# quick-fedora-mirror wants a root dir without module name

mkdir /mirror/
chown -R "$OWNER" /mirror/

typeset -g -A MODULEMAPPING
MODULEMAPPING=(
[fedora-alt]=alt
[fedora-archive]=archive
[fedora-enchilada]=fedora
[fedora-epel]=epel
[fedora-secondary]=fedora-secondary
)

if [[ -z $MODULE ]]; then
    echo 'No module set'
    exit 1
fi

_MODULE_DIR="${MODULEMAPPING[$MODULE]}"

if [[ -z $_MODULE_DIR ]]; then
    echo 'Wrong module'
    exit 1
fi

ln -s "$TO" "/mirror/$_MODULE_DIR"

_RSYNCOPTS=(-aSH -f "'R .~tmp~'" --keep-dirlinks --stats --preallocate --delay-updates "--out-format='@ %i  %n%L'")

if [[ -n "${BIND_ADDRESS:+1}" ]]; then
    if [[ "$BIND_ADDRESS" =~ .*: ]]; then
        _RSYNCOPTS+=(-6 --address "$BIND_ADDRESS")
    else
        _RSYNCOPTS+=(-4 --address "$BIND_ADDRESS")
    fi
fi

_REMOTE=${REMOTE:-rsync://dl.fedoraproject.org}
_RSYNC_TIMEOUT=${RSYNC_TIMEOUT:-600}
_VERBOSE=${VERBOSE:-7}

cat > "$_CONF_FILE" << EOF
DESTD=/mirror/
TIMEFILE=$LOGDIR/timefile
REMOTE=$_REMOTE
MODULES=($MODULE)
RSYNCTIMEOUT=$_RSYNC_TIMEOUT
RSYNCOPTS=(${_RSYNCOPTS[@]})
CHECKIN_SITE=${CHECKIN_SITE:-''}
CHECKIN_PASSWORD=${CHECKIN_PASSWORD:-''}
CHECKIN_HOST=${CHECKIN_HOST:-''}
VERBOSE=$_VERBOSE
LOGFILE=$LOGFILE
FILTEREXP=${FILTEREXP:-''}
EOF

cat "$_CONF_FILE"
