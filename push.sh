#!/bin/bash

[[ $DEBUG = true ]] && set -x

if [[ $TRAVIS_EVENT_TYPE != 'push' && $TRAVIS_EVENT_TYPE != 'cron' ]]; then
    exit 0
fi
if [[ $TRAVIS_EVENT_TYPE == 'push' && $TRAVIS_BRANCH != 'master' ]]; then
    exit 0
fi

[[ -z $SKIP_LOGIN ]] && docker login -u "$DOCKER_USER" -p "$DOCKER_PASS"

docker images --filter=label=ustcmirror.images --format="{{.Repository}}:{{.Tag}}" | xargs docker push
