FROM ustcmirror/base:alpine
MAINTAINER Keyu Tao <taoky@ustclug.org>
RUN apk add --no-cache --update wget perl ca-certificates git python3 py3-requests py3-pip && \
    pip install pyquery && \
    mkdir -p /usr/local/lib/tunasync
ADD tunasync /usr/local/lib/tunasync
ADD sync.sh /
