#!/bin/bash
log() {
    echo "$@" >&2
}

if [[ ! -x /sync.sh ]]; then
    log '/sync.sh not found'
    exit 1
fi

. /sync.sh