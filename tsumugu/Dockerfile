FROM ustcmirror/base:alpine
LABEL maintainer="Keyu Tao <taoky AT ustclug.org>"
ARG TSUMUGU_VERSION=20240715

RUN apk add --no-cache wget ca-certificates && \
    cd /tmp/ && wget -q "https://github.com/taoky/tsumugu/releases/download/${TSUMUGU_VERSION}/tsumugu" && \
    mv /tmp/tsumugu /usr/local/bin/ && \
    chmod +x /usr/local/bin/tsumugu && \
    rm -rf /tmp/* && apk del wget

ADD sync.sh /
