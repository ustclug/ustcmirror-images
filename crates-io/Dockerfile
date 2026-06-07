FROM ustcmirror/crates-io-index
LABEL maintainer="Keyu Tao <taoky AT ustclug.org>"

RUN apk add --no-cache python3 py3-tqdm ca-certificates

ADD sync-crates.sh /sync-crates.sh
ADD sync-crates.py /sync-crates.py
ADD utils_crates.py /utils_crates.py
ADD cleanup-crates.py /cleanup-crates.py
ADD upstream.sh /
ENV SYNC_SCRIPT=/sync-crates.sh
