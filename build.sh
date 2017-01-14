#!/bin/bash

set -e

[[ -n $DEBUG ]] && set -x

is_modified() {
    [[ -n $(git diff HEAD^ HEAD -- "$1") || -n $(git diff HEAD^ HEAD -- "build-$1.sh") ]]
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
else
    for MIRROR in "${methods[@]}"; do
        script="build-$MIRROR.sh"
        if is_modified "$script"; then
            export MIRROR
            . "$script"
        fi
    done
fi

is_modified "test" && . "build-test.sh"
