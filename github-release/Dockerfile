FROM ustcmirror/base:alpine
LABEL maintainer="Yulong Ming <myl.ustc@gmail.com>"
LABEL bind_support=true
RUN apk add --no-cache python3 py3-requests py3-yaml && \
    mkdir -p /usr/local/lib/tunasync
ADD tunasync /usr/local/lib/tunasync
ADD sync.sh /
