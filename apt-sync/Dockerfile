FROM ghcr.io/ustcmirror/base:alpine
MAINTAINER iBug <docker@ibugone.com>
RUN apk add --no-cache --update wget perl ca-certificates git python3 py3-requests && \
    mkdir -p /usr/local/lib/tunasync
ADD tunasync /usr/local/lib/tunasync
ADD sync.sh sync.py /
