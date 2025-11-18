FROM ustcmirror/base:alpine
LABEL maintainer="Keyu Tao <taoky AT ustclug.org>"
LABEL bind_support=true
ARG TSUMUGU_VERSION=20251111.0

RUN <<EOF
    set -euo pipefail
    apk add --no-cache wget ca-certificates
    cd /tmp/ && wget -q "https://github.com/taoky/tsumugu/releases/download/${TSUMUGU_VERSION}/tsumugu"
    mv /tmp/tsumugu /usr/local/bin/
    chmod +x /usr/local/bin/tsumugu
    rm -rf /tmp/* && apk del wget
EOF

ADD sync.sh /
