#!/bin/bash

f="$MIRROR/Dockerfile"

cat << EOF > "$f"
FROM ustcmirror/base:alpine
MAINTAINER Jian Zeng <anonymousknight96 AT gmail.com>
ENTRYPOINT ["/entry.sh"]
ADD sync.sh /
VOLUME ["/data", "/log"]
RUN apk update && apk add --update git && \
    rm -rf /var/cache/apk/*
EOF

docker build -t "$ORG/$MIRROR" "$MIRROR"
docker push "$ORG/$MIRROR"

rm "$f"
