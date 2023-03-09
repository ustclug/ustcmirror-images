FROM ustcmirror/base:alpine
LABEL maintainer "YR Chen <stevapple@icloud.com>"

ADD ["sync.sh", "sync-repo.js", "utilities.js", "package.json", "package-lock.json", "/"]

RUN apk add --no-cache nodejs

RUN apk add --no-cache npm python3 && \
    npm ci --prefix / --only=production && \
    npm cache clean --force && \
    apk del --purge --no-cache npm python3
