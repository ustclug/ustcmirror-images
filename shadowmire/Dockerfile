FROM ustcmirror/base:alpine
LABEL maintainer="Keyu Tao <taoky AT ustclug.org>"
ARG COMMIT=bbcab99b4d83f9316b7da0ca6adaee53e4dccdc8

RUN <<EOF
    set -euo pipefail
    apk add --no-cache wget ca-certificates python3 py3-click py3-requests py3-tqdm
    cd /tmp/ && wget -q "https://raw.githubusercontent.com/taoky/shadowmire/$COMMIT/shadowmire.py"
    mv /tmp/shadowmire.py /usr/local/bin/shadowmire
    chmod +x /usr/local/bin/shadowmire
    rm -rf /tmp/* && apk del wget
EOF

ADD sync.sh /
