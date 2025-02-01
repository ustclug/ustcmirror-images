FROM ustcmirror/base:alpine
LABEL maintainer="Keyu Tao <taoky AT ustclug.org>"
LABEL bind_support=true
ARG YUKINA_VERSION=20250130

RUN <<EOF
    set -euo pipefail
    apk add --no-cache wget ca-certificates zstd
    cd /tmp/ && wget -q "https://github.com/taoky/yukina/releases/download/${YUKINA_VERSION}/yukina"
    mv /tmp/yukina /usr/local/bin/
    chmod +x /usr/local/bin/yukina
    rm -rf /tmp/* && apk del wget
EOF

ADD sync.sh /
