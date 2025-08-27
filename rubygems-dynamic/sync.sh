#!/bin/bash

set -e

SPEC_FILES=(latest_specs prerelease_specs specs)
SPEC_VERSION=4.8

# Fetch specs
for f in "${SPEC_FILES[@]}"; do
  fn="$TO/$f.$SPEC_VERSION"
  wget -O "$fn.gz.new" "$UPSTREAM/$fn.gz"
  gzip -cd "$fn.gz.new" > "$fn.new"
  mv -f "$fn.new" "$fn"
  mv -f "$fn.gz.new" "$fn.gz"
done

# Reset info API
find "$TO/info" -type f -delete

# Fetch index
wget -qO "$TO/versions.new" "$UPSTREAM/versions"
md5sum "$TO/versions.new" > "$TO/versions.md5sum.new"
mv -f "$TO/versions.new" "$TO/versions"
mv -f "$TO/versions.md5sum.new" "$TO/versions.md5sum"
