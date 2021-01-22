#!/bin/bash

set -e
[[ $DEBUG = true ]] && set -x

if [[ -n "$YUMSYNC_UNLINK" ]]; then
  DELETE=--delete
fi

if [[ -n "$YUMSYNC_DOWNLOAD_REPODATA" ]]; then
  DOWNLOAD_REPODATA=--download-repodata
fi

cd /usr/local/lib/tunasync
DISTS="$YUMSYNC_DISTS:"
while [[ "$DISTS" == *:* ]]; do
  THISDIST="${DISTS%%:*}|"
  DISTS="${DISTS#*:}"

  YUM_DIST="${THISDIST}"
  YUM_COMP="${YUM_DIST#*|}"
  YUM_ARCH="${YUM_COMP#*|}"
  YUM_REPO="${YUM_ARCH#*|}"
  YUM_DIR="${YUM_REPO#*|}"

  YUM_DIST="${THISDIST%%|*}"
  YUM_COMP="${YUM_COMP%%|*}"
  YUM_ARCH="${YUM_ARCH%%|*}"
  YUM_REPO="${YUM_REPO%%|*}"
  YUM_DIR="${YUM_DIR%%|*}"

  YUM_ARCH="${YUM_ARCH// /,}"
  YUM_COMP="${YUM_COMP// /,}"

  python3 yum-sync.py $DELETE $DOWNLOAD_REPODATA "$YUMSYNC_URL" "$YUM_DIST" "$YUM_COMP" "$YUM_ARCH" "$YUM_REPO" "${TO}/${YUM_DIR}"
done