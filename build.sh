#!/bin/bash

set -e
[[ $DEBUG = true ]] && set -x

NOW=$(date +%Y%m%d)
export NOW
export ORG=ustcmirror

TRAVIS_EVENT_TYPE=${TRAVIS_EVENT_TYPE:-}
TRAVIS_COMMIT_RANGE=${TRAVIS_COMMIT_RANGE:-'origin/master...HEAD'}

if [[ $TRAVIS_EVENT_TYPE = 'cron' ]]; then
    BUILD_ALL=1
else
    BUILD_ALL=${BUILD_ALL:-0}
fi

is_modified() {
    local COMMIT_FROM=${TRAVIS_COMMIT_RANGE%...*}
    local COMMIT_TO=${TRAVIS_COMMIT_RANGE#*...}
    [[ -n $(git diff "$COMMIT_FROM" "$COMMIT_TO" -- "$1") ]]
}

build_image() {
    local image="$1"
    if [[ -x $image/build.sh ]]; then
        (cd "$image" && ./build.sh)
    else
        docker build -t "$ORG/$image" --label "$ORG.images" "$image"
    fi

    if [[ $TRAVIS_EVENT_TYPE != 'cron' ]]; then
        if [[ $image != 'base' ]]; then
            docker tag "$ORG/$image:latest" "$ORG/$image:$NOW"
        else
            docker tag "$ORG/$image:alpine" "$ORG/$image:alpine-$NOW"
            docker tag "$ORG/$image:debian" "$ORG/$image:debian-$NOW"
        fi
    fi
}

# match all directories
tmp=(*/)
# remove splitters
derived=(${tmp[@]%/})
# remove base
derived=(${derived[@]/base})

#########################################
### Images based on ustcmirror/base
#########################################
if is_modified "base" || [[ $BUILD_ALL -eq 1 ]]; then
    build_image base
    for image in "${derived[@]}"; do
        build_image "$image"
    done
else
    for image in "${derived[@]}"; do
        is_modified "$image" && build_image "$image"
    done
fi

exit 0
