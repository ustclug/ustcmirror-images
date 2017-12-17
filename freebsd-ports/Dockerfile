FROM ustcmirror/gitsync
LABEL maintainer="Yifan Gao <docker@yfgao.com>"
RUN apk add --no-cache curl coreutils parallel gawk sed grep tar findutils bash
ADD sync-ports.sh /
ENV SYNC_SCRIPT=/sync-ports.sh
