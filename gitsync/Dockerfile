FROM ustcmirror/base:alpine
LABEL maintainer="Jian Zeng <anonymousknight96 AT gmail.com>"
RUN apk add --no-cache git && \
    git config set --system pack.windowMemory 100m && \
    git config set --system pack.threads 2 && \
    git config set --system maintenance.auto false
ADD sync.sh upstream.sh /
