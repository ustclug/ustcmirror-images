FROM ustcmirror/base:alpine
LABEL maintainer="iBug <docker@ibugone.com>"
LABEL bind_support=true
RUN apk add --no-cache --update wget perl ca-certificates git python3 py3-requests && \
    mkdir -p /usr/local/lib/tunasync
ADD tunasync /usr/local/lib/tunasync
ADD sync.sh sync.py /
