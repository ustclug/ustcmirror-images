FROM ustcmirror/base:alpine
LABEL maintainer "Keyu Tao <taoky AT lug.ustc.edu.cn>"
RUN apk add --no-cache git curl && \
    curl -fLo /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo && \
    chmod +x /usr/local/bin/repo
ADD sync.sh /
