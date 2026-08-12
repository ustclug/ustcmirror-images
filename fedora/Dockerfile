FROM ustcmirror/base:alpine
LABEL maintainer="Shengjing Zhu <zsj950618@gmail.com>"
LABEL bind_support=true
RUN <<EOF
    set -euo pipefail
    apk add --no-cache zsh curl rsync ca-certificates gawk grep bzip2 coreutils diffutils findutils
EOF
COPY quick-fedora-mirror /usr/local/bin/quick-fedora-mirror
ADD ["pre-sync.sh", "sync.sh", "upstream.sh", "/"]
