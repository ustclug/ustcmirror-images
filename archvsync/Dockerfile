FROM ustcmirror/base:alpine
LABEL maintainer "Jian Zeng <anonymousknight96 AT gmail.com>"
LABEL ustcmirror.images ""
ENV BASEDIR /usr/local
RUN apk add --no-cache rsync
ADD ["common", "ftpsync", "$BASEDIR/bin/"]
ADD ["sync.sh", "pre-sync.sh", "/"]
