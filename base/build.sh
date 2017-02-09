#!/bin/bash

set -ex

for i in Dockerfile.*; do
    tag="ustcmirror/base:${i##*.}"
    docker build -f "$i" -t "$tag" --label ustcmirror.images .
done
