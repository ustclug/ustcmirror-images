#!/bin/bash

set -e

SPEC_FILES=(latest_specs prerelease_specs specs)
SPEC_VERSION=4.8

# Fetch specs
for f in "${SPEC_FILES[@]}"; do
  urlpath="/$f.$SPEC_VERSION"
  fn="$TO$urlpath"
  wget -O "$fn.gz.new" "$UPSTREAM$urlpath.gz"
  gzip -cd "$fn.gz.new" > "$fn.new"
  touch -r "$fn.gz.new" "$fn.new"
  mv -f "$fn.new" "$fn"
  mv -f "$fn.gz.new" "$fn.gz"
done

# Reset info API
mkdir -p "$TO/info"
find "$TO/info" -type f -delete

# Fetch index
wget -qO "$TO/versions.new" "$UPSTREAM/versions"
md5sum "$TO/versions.new" > "$TO/versions.md5sum.new"
touch -r "$TO/versions.new" "$TO/versions.md5sum.new"
mv -f "$TO/versions.new" "$TO/versions"
mv -f "$TO/versions.md5sum.new" "$TO/versions.md5sum"
