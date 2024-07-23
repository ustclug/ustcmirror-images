FROM ustcmirror/base:alpine
LABEL maintainer="Yao Wei (魏銘廷) <mwei@lxde.org>"

RUN apk add --no-cache python3 py-setuptools openssl libffi && \
    apk add --no-cache --virtual .build-deps gcc musl-dev python3-dev py3-pip openssl-dev libffi-dev && \
    pip3 install --upgrade pip && \
    pip3 --no-cache-dir install gsutil

ADD pre-sync.sh sync.sh /
