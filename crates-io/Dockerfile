FROM ustcmirror/crates-io-index
LABEL maintainer="Keyu Tao <taoky AT ustclug.org>"

RUN apk add --no-cache python3 ca-certificates

ADD sync.sh /sync.sh
ADD sync-crates.py /sync-crates.py
ENV SYNC_SCRIPT=/sync.sh
