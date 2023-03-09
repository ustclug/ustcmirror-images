FROM ustcmirror/base:alpine
LABEL maintainer "YR Chen <stevapple@icloud.com>"

RUN apk add --no-cache nodejs

ADD ["package.json", "package-lock.json", "/"]
RUN apk add --no-cache npm python3 && \
    npm ci --prefix / --only=production && \
    npm cache clean --force && \
    apk del --purge --no-cache npm python3

ADD ["sync.sh", "sync-repo.js", "utilities.js", "/"]
