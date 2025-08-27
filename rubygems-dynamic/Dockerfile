FROM ustcmirror/base:alpine
LABEL maintainer="Yifan Gao <docker@yfgao.com>"
ENV UPSTREAM=https://rubygems.org
RUN apk add --no-cache wget
ADD sync.sh /
