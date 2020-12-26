#!/bin/bash

[[ $DEBUG = true ]] && set -x

if [[ $GITHUB_EVENT != push && $GITHUB_EVENT != schedule ]]; then
    exit 0
fi
if [[ $GITHUB_EVENT == push && $GITHUB_REF != "refs/heads/master" ]]; then
    exit 0
fi

[[ -z $SKIP_LOGIN ]] && docker login -u "$DOCKER_USER" -p "$DOCKER_PASS"

for image in $(docker images --filter=label=org.ustcmirror.images=true --format="{{.Repository}}:{{.Tag}}")
do
    docker push "$image"
    echo "$image pushed"
done

