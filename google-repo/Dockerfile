FROM ustcmirror/base:alpine
LABEL maintainer="Keyu Tao <taoky AT lug.ustc.edu.cn>"
RUN <<EOF
    set -euo pipefail
    apk add --no-cache git curl python3 openssh-client gnupg
    curl -fLo /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
    chmod +x /usr/local/bin/repo
    git config set --system pack.windowMemory 100m
    git config set --system pack.threads 2
    git config set --system maintenance.autoDetach false
EOF
ADD ["pre-sync.sh", "sync.sh", "upstream.sh", "/"]
