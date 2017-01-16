#!/bin/bash

set -e
[[ $DEBUG = [tT]rue ]] && set -x
LAST="${LAST:-HEAD^}"

is_modified() {
    [[ -n $(git diff "$LAST" HEAD -- "$1" "build-$1.sh") ]]
}

docker login -u "$DOCKER_USER" -p "$DOCKER_PASS"
export ORG=ustcmirror

methods=(*sync)

if is_modified "base"; then
    . "build-base.sh"
    for MIRROR in "${methods[@]}"; do
        script="build-$MIRROR.sh"
        export MIRROR
        . "$script"
    done
    . "build-test.sh"
else
    for MIRROR in "${methods[@]}"; do
        script="build-$MIRROR.sh"
        if is_modified "$MIRROR"; then
            export MIRROR
            . "$script"
        fi
    done
    is_modified "test" && . "build-test.sh"
fi

exit 0
