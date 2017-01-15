#!/bin/bash

tag='ustcmirror/test:latest'

cat << EOF > "test/Dockerfile"
FROM ustcmirror/base:debian
MAINTAINER Jian Zeng <anonymousknight96 AT gmail.com>
ENTRYPOINT ["/sync.sh"]
ADD sync.sh /
EOF

docker build -t "$tag" test
docker push "$tag"
