#!/bin/bash

tag='ustcmirror/base:debian'

cat << EOF > "base/Dockerfile"
FROM debian:jessie-slim
MAINTAINER Jian Zeng <anonymousknight96 AT gmail.com>
ADD entry.sh /
EOF

docker build -t "$tag" base
docker push "$tag"

########################################

tag='ustcmirror/base:alpine'

cat << EOF > "base/Dockerfile"
FROM alpine:3.5
MAINTAINER Jian Zeng <anonymousknight96 AT gmail.com>
ADD entry.sh /
RUN apk update && apk add --update bash tzdata && rm -rf /var/cache/apk/* \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
EOF

docker build -t "$tag" base
docker push "$tag"
