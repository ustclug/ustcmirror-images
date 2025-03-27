FROM ustcmirror/base:alpine
LABEL maintainer="Keyu Tao <taoky AT ustclug.org>"

RUN <<EOF
    set -euo pipefail
    apk add --no-cache python3 py3-httpx
EOF

ADD sync.sh /
ADD sync.py /
