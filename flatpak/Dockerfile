FROM ustcmirror/base:alpine
LABEL maintainer="Keyu Tao <taoky AT ustclug.org>"

RUN <<EOF
    set -euo pipefail
    apk add --no-cache python3 py3-gobject3 py3-requests
EOF

ADD sync.sh /
ADD sync.py /
