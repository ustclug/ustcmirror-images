FROM ghcr.io/ustcmirror/base:alpine
LABEL maintainer "Keyu Tao <taoky AT lug.ustc.edu.cn>"
RUN apk add --no-cache git curl python3 openssh-client gnupg && \
    curl -fLo /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo && \
    sed -i 's|^#!/usr/bin/env python|#!/usr/bin/python3|' /usr/local/bin/repo && \
    chmod +x /usr/local/bin/repo
ADD ["pre-sync.sh", "sync.sh", "/"]
