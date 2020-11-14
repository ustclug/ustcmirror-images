#!/bin/bash

set -e
[[ $DEBUG = true ]] && set -x

if [[ -n "$USE_CREATEREPO" ]]; then
  DOWNLOAD_REPODATA=
else
  DOWNLOAD_REPODATA=--download-repodata
fi

cd /usr/local/lib/tunasync
DISTS="$YUMSYNC_DISTS:"
YUM_REPONAME=${YUM_REPONAME:-"@{comp}-el@{os_ver}"}
while [[ "$DISTS" == *:* ]]; do
  THISDIST="${DISTS%%:*}|"
  DISTS="${DISTS#*:}"

  YUM_DIST="${THISDIST}"
  YUM_COMP="${YUM_DIST#*|}"
  YUM_ARCH="${YUM_COMP#*|}"
  YUM_DIR="${YUM_ARCH#*|}"

  YUM_DIST="${THISDIST%%|*}"
  YUM_COMP="${YUM_COMP%%|*}"
  YUM_ARCH="${YUM_ARCH%%|*}"
  YUM_DIR="${YUM_DIR%%|*}"

  YUM_ARCH="${YUM_ARCH// /,}"
  YUM_COMP="${YUM_COMP// /,}"

  exec python3 yum-sync.py "$YUMSYNC_URL" "$YUM_DIST" "$YUM_COMP" "$YUM_ARCH" "$YUM_REPONAME" "${TO}/${YUM_DIR}" $DOWNLOAD_REPODATA
done
