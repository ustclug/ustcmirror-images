FROM ustcmirror/base:alpine
MAINTAINER Jian Zeng <anonymousknight96 AT gmail.com>
RUN apk update && apk add --update lftp && \
    rm -rf /var/cache/apk/*
ADD sync.sh /
