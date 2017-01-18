FROM ustcmirror/base:alpine
MAINTAINER Jian Zeng <anonymousknight96 AT gmail.com>
ENTRYPOINT ["/entry.sh"]
ADD sync.sh /
VOLUME ["/data", "/log"]
RUN apk update && apk add --update lftp && \
    rm -rf /var/cache/apk/*
