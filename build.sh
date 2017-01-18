#!/bin/bash

set -e
[[ $DEBUG = [tT]rue ]] && set -x
LAST="${LAST:-HEAD^}"
export ORG=ustcmirror

is_modified() {
    [[ -n $(git diff "$LAST" HEAD -- "$1") ]]
}

build_image() {
    local image="$1"
    if [[ -x $image/build.sh ]]; then
        . "$image/build.sh"
    else
        docker build -t "$ORG/$image" "$image"
        docker push "$ORG/$image"
    fi
}

docker login -u "$DOCKER_USER" -p "$DOCKER_PASS"

mirrors=(*sync 'test')
#########################################
### Images based on ustcmirror/base
#########################################
if is_modified "base"; then
    . "base/build.sh"
    for image in "${mirrors[@]}"; do
        build_image "$image"
    done
else
    for image in "${mirrors[@]}"; do
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
