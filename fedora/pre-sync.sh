#!/bin/bash

_CONF_FILE='/etc/quick-fedora-mirror.conf'
LOGDIR="${LOGDIR%%/}"

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


# quick-fedora-mirror wants a root dir without module name

# hack fedora-enchilada directory.
# we previously synced /fedora/linux/ to /fedora/
mkdir /mirror/
chown "$OWNER" /mirror/

if [[ "$MODULE" = "fedora-enchilada" ]]; then
    su-exec "$OWNER" mkdir -p "$LOGDIR"/filelists/
    su-exec "$OWNER" ln -sf "$LOGDIR/filelists" /mirror/fedora
    su-exec "$OWNER" ln -snf "$TO" /mirror/fedora/linux
else
    su-exec "$OWNER" ln -s "$TO" "/mirror/$_MODULE_DIR"
fi

# see quick-fedora-mirror set_default_vars()
_RSYNCOPTS=(-aSH -f "'R .~tmp~'" --keep-dirlinks --stats --delay-updates "--out-format='@ %i %10l  %n%L'")

if [[ -n "${BIND_ADDRESS:+1}" ]]; then
    if [[ "$BIND_ADDRESS" =~ .*: ]]; then
        _RSYNCOPTS+=(-6 --address "$BIND_ADDRESS")
    else
        _RSYNCOPTS+=(-4 --address "$BIND_ADDRESS")
    fi
fi

_REMOTE=${REMOTE:-rsync://dl.fedoraproject.org}
_RSYNC_TIMEOUT=${RSYNC_TIMEOUT:-14400}
_VERBOSE=${VERBOSE:-7}
_MAXDELETE=${MAXDELETE:-4000}
_FILTER_FILE=''

# FILTEREXP may contain one extended regular expression per line.  Keep the
# expressions out of the sourced zsh configuration so shell metacharacters in
# them (such as | and parentheses) are not interpreted as shell syntax.
if [[ -n $FILTEREXP ]]; then
    _FILTER_FILE='/etc/quick-fedora-mirror.filters'
    printf '%s\n' "$FILTEREXP" > "$_FILTER_FILE"
fi

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
MAXDELETE=$_MAXDELETE
LOGFILE=$LOGFILE
FILTERFILE=$_FILTER_FILE
EOF

cat "$_CONF_FILE"
