FROM ustcmirror/base:alpine
LABEL maintainer="Jian Zeng <anonymousknight96 AT gmail.com>"
ENV APTSYNC_NTHREADS=20 \
    APTSYNC_UNLINK=0
RUN apk add --no-cache --update wget perl ca-certificates xz \
        && mkdir -p /var/spool/apt-mirror/mirror /var/spool/apt-mirror/skel /etc/apt/ \
        && wget -nv -O /usr/local/bin/apt-mirror 'https://raw.githubusercontent.com/apt-mirror/apt-mirror/master/apt-mirror' \
        && chmod +x /usr/local/bin/apt-mirror
ADD ["pre-sync.sh", "sync.sh", "/"]
