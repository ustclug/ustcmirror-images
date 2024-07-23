FROM ustcmirror/base:alpine
LABEL maintainer="Shengjing Zhu <zsj950618@gmail.com>"
LABEL bind_support=true
RUN apk add --no-cache zsh curl rsync ca-certificates gawk grep bzip2 coreutils diffutils findutils \
    && curl -fLo /usr/local/bin/quick-fedora-mirror https://pagure.io/quick-fedora-mirror/raw/master/f/quick-fedora-mirror \
    && chmod +x /usr/local/bin/quick-fedora-mirror
ADD ["pre-sync.sh", "sync.sh", "/"]
