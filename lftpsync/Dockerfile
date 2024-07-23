FROM ustcmirror/base:alpine
LABEL maintainer="Jian Zeng <anonymousknight96 AT gmail.com>"
LABEL bind_support=true
RUN apk add --no-cache lftp ca-certificates
ADD sync.sh /
