FROM ustcmirror/curl-helper
LABEL maintainer="Yifan Gao docker@yfgao.com"
RUN apk add --no-cache rsync parallel gawk sed xz tar jq bash zstd python3
ADD sync.sh scan_and_clean_mismatched_files.py /
