#!/bin/bash

set -e
[[ $DEBUG = true ]] && set -x
export ORG=ustcmirror

is_modified() {
    [[ -z $TRAVIS_COMMIT_RANGE ]] && return 1 # false
    local COMMIT_FROM=${TRAVIS_COMMIT_RANGE%...*}
    local COMMIT_TO=${TRAVIS_COMMIT_RANGE#*...}
    [[ -n $(git diff "$COMMIT_FROM" "$COMMIT_TO" -- "$1") ]]
}

build_image() {
    local image="$1"
    if [[ -x $image/build.sh ]]; then
        (cd "$image" && ./build.sh)
    else
        docker build -t "$ORG/$image" --label ustcmirror.images "$image"
    fi
}

derived=(*sync 'test')
#########################################
### Images based on ustcmirror/base
#########################################
if is_modified "base"; then
    build_image base
    for image in "${derived[@]}"; do
        build_image "$image"
    done
else
    for image in "${derived[@]}"; do
        is_modified "$image" && build_image "$image"
    done
fi

############################################
### Images dosen't based on ustcmirror/base
############################################
others=(mongodb)
for image in "${others[@]}"; do
    is_modified "$image" && build_image "$image"
done

exit 0
