FROM ustcmirror/base:alpine
LABEL maintainer="Keyu Tao <taoky AT ustclug.org>"
LABEL bind_support=true

RUN <<EOF
    set -euo pipefail
    apk add --no-cache python3 py3-httpx
EOF

ADD sync.sh sync.py upstream.sh /
