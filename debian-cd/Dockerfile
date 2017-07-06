FROM ustcmirror/base:alpine
LABEL maintainer "Jian Zeng <anonymousknight96 AT gmail.com>"
RUN apk add --no-cache wget ca-certificates rsync && mkdir -p /etc/jigdo
ADD ["jigdo-mirror", "cd-mirror", "/usr/local/bin/"]
ADD jigdo-mirror.conf.in /etc/jigdo/
ADD ["sync.sh", "pre-sync.sh", "/"]
