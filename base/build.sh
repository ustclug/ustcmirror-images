#!/bin/bash

set -e
set -x

ls Dockerfile.* | 
while read DOCKERFILE; do
    tag="ustcmirror/base:${DOCKERFILE##*.}"
    docker build -f $DOCKERFILE -t "$tag" --label ustcmirror.images .
    docker push "$tag"
done
