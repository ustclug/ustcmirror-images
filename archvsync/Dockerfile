FROM ustcmirror/base:alpine
LABEL maintainer="Jian Zeng <anonymousknight96 AT gmail.com>"
LABEL bind_support=true
ENV BASEDIR=/usr/local
RUN apk add --no-cache rsync && mkdir -p "$BASEDIR/etc"
ADD ["common", "ftpsync", "$BASEDIR/bin/"]
ADD ["sync.sh", "pre-sync.sh", "/"]
