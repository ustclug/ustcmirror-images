FROM ustcmirror/base:alpine
LABEL maintainer="Yifan Gao docker@yfgao.com"
RUN apk add --no-cache curl coreutils rsync parallel gawk sed grep xz tar jq findutils bash
ADD sync.sh /
