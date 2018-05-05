FROM ustcmirror/base:alpine
LABEL maintainer="Jian Zeng <anonymousknight96 AT gmail.com>"
ENV APTSYNC_NTHREADS=20 \
    APTSYNC_UNLINK=0
RUN apk add --no-cache --update wget perl ca-certificates xz \
        && mkdir -p /var/spool/apt-mirror/ /etc/apt/
ADD ["apt-mirror", "/usr/local/bin"]
ADD ["pre-sync.sh", "sync.sh", "/"]
