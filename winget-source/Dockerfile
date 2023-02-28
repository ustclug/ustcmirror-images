FROM ustcmirror/base:alpine
LABEL maintainer "YR Chen <stevapple@icloud.com>"

ADD ["sync.sh", "sync-repo.js", "utilities.js", "package.json", "package-lock.json", "/"]

RUN apk add --no-cache nodejs npm python3
RUN cd / && npm install
