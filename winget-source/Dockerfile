FROM ustcmirror/base:alpine
LABEL maintainer="YR Chen <stevapple@icloud.com>"
LABEL bind_support=true

RUN apk add --no-cache nodejs

ADD ["package.json", "package-lock.json", "/"]
RUN <<EOF
    set -euo pipefail
    apk add --no-cache npm python3
    npm ci --prefix / --only=production
    npm cache clean --force
    apk del --purge --no-cache npm python3
EOF
RUN 

ADD ["sync.sh", "sync-repo.js", "sysexits.js", "utilities.js", "/"]
