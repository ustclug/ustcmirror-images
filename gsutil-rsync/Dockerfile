FROM ustcmirror/base:alpine
LABEL maintainer="Yao Wei (魏銘廷) <mwei@lxde.org>"

RUN <<EOF
    set -euo pipefail
    apk add --no-cache python3 py-setuptools openssl libffi py3-pip
    pip3 install --upgrade pip
    pip3 --no-cache-dir install gsutil
EOF
ADD pre-sync.sh sync.sh /
