FROM ghcr.io/ustcmirror/base:alpine
LABEL maintainer "Yulong Ming <myl.ustc@gmail.com>"
RUN apk add --no-cache python3 py3-requests py3-yaml && \
    mkdir -p /usr/local/lib/tunasync
ADD tunasync /usr/local/lib/tunasync
ADD sync.sh /
