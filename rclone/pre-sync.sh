#!/bin/sh

remote_type="$RCLONE_CONFIG_REMOTE_TYPE"
path="$RCLONE_PATH"
domain=""

case "$remote_type" in
  "swift")
    domain="$RCLONE_SWIFT_STORAGE_URL/"
    ;;
  "http")
    domain="$RCLONE_CONFIG_REMOTE_URL"
    ;;
  "s3")
    domain="$RCLONE_CONFIG_REMOTE_ENDPOINT"
    ;;
  "webdav")
    domain="$RCLONE_CONFIG_REMOTE_URL"
    ;;
esac

set_upstream "${domain}${path}"
