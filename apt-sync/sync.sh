#!/bin/bash

set -e
[[ $DEBUG = true ]] && set -x

if [[ -n "$APTSYNC_UNLINK" ]]; then
  DELETE=--delete
fi

cd /usr/local/lib/tunasync
DISTS="$APTSYNC_DISTS:"
while [[ "$DISTS" == *:* ]]; do
  THISDIST="${DISTS%%:*}|"
  DISTS="${DISTS#*:}"

  APT_DIST="${THISDIST}"
  APT_COMP="${APT_DIST#*|}"
  APT_ARCH="${APT_COMP#*|}"
  APT_DIR="${APT_ARCH#*|}"

  APT_DIST="${THISDIST%%|*}"
  APT_COMP="${APT_COMP%%|*}"
  APT_ARCH="${APT_ARCH%%|*}"
  APT_DIR="${APT_DIR%%|*}"

  APT_ARCH="${APT_ARCH// /,}"
  APT_COMP="${APT_COMP// /,}"

  python3 apt-sync.py $DELETE "$APTSYNC_URL""${APT_DIR}" "$APT_DIST" "$APT_COMP" "$APT_ARCH" "${TO}/${APT_DIR}"
done
