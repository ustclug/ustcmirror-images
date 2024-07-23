FROM ustcmirror/base:alpine
LABEL maintainer="Jian Zeng <anonymousknight96 AT gmail.com>"
LABEL bind_support=true
VOLUME ["/debian"]
ADD ["sync.sh", "pre-sync.sh", "prepare.sh", "/"]
ADD ["jigdo-mirror", "cd-mirror", "/usr/local/bin/"]
ADD jigdo-mirror.conf.in /etc/jigdo/
RUN /prepare.sh && rm /prepare.sh
