FROM ustcmirror/base:alpine
LABEL maintainer="Yifan Gao <docker@yfgao.com>"
ENV UPSTREAM=http://rubygems.org
RUN apk add --no-cache ruby ca-certificates && \
    gem install --no-document rubygems-mirror
ADD sync.sh pre-sync.sh /
