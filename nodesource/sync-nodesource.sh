#!/bin/bash

BASE=$TO
export TO=
export LFTPSYNC_PATH=
export LFTPSYNC_EXCLUDE="-X db/ -X conf/"

sync_nodesource(){
    local DIST=$1; shift
    while [[ $# -gt 0 ]]; do
        local VERSION=$1; shift
        local DIR=$BASE/$DIST/$VERSION
        mkdir -p $DIR && cd $DIR || exit 1
        export LFTPSYNC_HOST=https://$DIST.nodesource.com/$VERSION/
        /sync.sh
    done
}

sync_nodesource deb node_{4..8}.x node_0.1{0,2} iojs_{1..3}.x
sync_nodesource rpm pub_{4..8}.x pub_0.1{0,2}
