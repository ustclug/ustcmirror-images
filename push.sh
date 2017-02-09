#!/bin/bash

[[ $TRAVIS_EVENT_TYPE != 'push' || $TRAVIS_BRANCH != 'master' ]] && exit 0

[[ -z $SKIP_LOGIN ]] && docker login -u "$DOCKER_USER" -p "$DOCKER_PASS"

docker images --filter=label=ustcmirror.images --format="{{.Repository}}:{{.Tag}}" | \
while read -r TAG; do
    docker push "$TAG"
done
