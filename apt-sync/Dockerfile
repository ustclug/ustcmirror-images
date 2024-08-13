FROM ustcmirror/base:alpine
LABEL maintainer="iBug <docker@ibugone.com>"
LABEL bind_support=true
RUN <<EOF
    set -euo pipefail
    apk add --no-cache --update wget perl ca-certificates git python3 py3-requests
    mkdir -p /usr/local/lib/tunasync
EOF
ADD tunasync /usr/local/lib/tunasync
ADD sync.sh sync.py /
