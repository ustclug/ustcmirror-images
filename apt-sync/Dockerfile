FROM ustcmirror/base:alpine
MAINTAINER iBug <docker@ibugone.com>
RUN apk add --no-cache --update wget perl ca-certificates git python3 && \
    mkdir -p /usr/local/lib/tunasync
ADD tunasync /usr/local/lib/tunasync
ADD sync.sh /
