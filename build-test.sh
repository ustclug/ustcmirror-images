#!/bin/bash

tag='ustcmirror/test:latest'

cat << EOF > "test/Dockerfile"
FROM debian:jessie-slim
MAINTAINER Jian Zeng <anonymousknight96 AT gmail.com>
ENTRYPOINT ["/entry.sh"]
ADD entry.sh /
EOF

docker build -t "$tag" test
docker push "$tag"
