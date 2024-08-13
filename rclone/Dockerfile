FROM ustcmirror/base:alpine
LABEL maintainer="Jian Zeng <anonymousknight96 AT gmail.com>"
LABEL bind_support=true

ARG RCLONE_VERSION=v1.50.2
ENV RCLONE_DELETE_AFTER=true \
    RCLONE_DELETE_EXCLUDED=true

RUN <<EOF
    set -euo pipefail
    apk add --no-cache wget ca-certificates
    cd /tmp/ && wget -q "https://downloads.rclone.org/$RCLONE_VERSION/rclone-$RCLONE_VERSION-linux-amd64.zip"
    unzip /tmp/rclone*.zip
    mv /tmp/rclone-*/rclone /usr/local/bin/
    rm -rf /tmp/* && apk del wget
EOF

ADD sync.sh /
