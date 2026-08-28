FROM ustcmirror/rclone:latest
LABEL maintainer="USTC Mirror Maintainers <lug@ustc.edu.cn>"

RUN apk add --no-cache git && \
    git config set --system pack.windowMemory 100m && \
    git config set --system pack.threads 2 && \
    git config set --system maintenance.auto false

ADD sync.sh upstream.sh /
