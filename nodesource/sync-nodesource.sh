#!/bin/bash

set -eu
[[ $DEBUG = true ]] && set -x

BASE=$TO
export LFTPSYNC_EXCLUDE="-X db/ -X conf/"

sync_nodesource(){
    local DIST=$1; shift
    for VERSION in "$@"; do
        export TO="$BASE/$DIST/$VERSION"
        export LFTPSYNC_HOST=https://$DIST.nodesource.com/$VERSION/
        mkdir -p "$TO"
        /sync.sh
    done
}

sync_nodesource deb node_{4..10}.x node_0.1{0,2} iojs_{1..3}.x
sync_nodesource rpm pub_{4..10}.x pub_0.1{0,2}
