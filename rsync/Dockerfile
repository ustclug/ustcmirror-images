FROM ustcmirror/base:alpine
MAINTAINER Jian Zeng <anonymousknight96 AT gmail.com>
ENTRYPOINT ["entry.sh"]
VOLUME ["/data", "/log"]
RUN apk update && apk add --update rsync && \
    rm -rf /var/cache/apk/*
ADD sync.sh /
