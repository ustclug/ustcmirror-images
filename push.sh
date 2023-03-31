#!/bin/bash

[[ $DEBUG = true ]] && set -x

case $GITHUB_EVENT_NAME in
    push|schedule|workflow_dispatch)
        if [[ $GITHUB_REF != "refs/heads/master" ]]; then
            exit 0
        fi
        ;;
    *)
        exit 0
        ;;
esac

[[ -z $SKIP_LOGIN ]] && docker login -u "$DOCKER_USER" -p "$DOCKER_PASS"

for image in $(docker images --filter=label=org.ustcmirror.images=true --format="{{.Repository}}:{{.Tag}}")
do
    docker push "$image" && echo "$image pushed to ghcr.io"
    docker tag "$image" "docker.io/${image##ghcr.io/}" && docker push "docker.io/${image##ghcr.io/}" && echo "$image pushed to docker.io"
done

