FROM ustcmirror/base:alpine
LABEL maintainer "Yulong Ming <myl.ustc@gmail.com>"
RUN apk add --no-cache python3 py3-requests && \
    mkdir -p /usr/local/lib/tunasync
ADD tunasync /usr/local/lib/tunasync
ADD sync.sh /
