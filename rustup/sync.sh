#!/bin/bash

set -eu
[[ $DEBUG = true ]] && set -x

echo "Running script"

export UPSTREAM="${UPSTREAM:-https://static.rust-lang.org/}"
export GC="${GC:-1}"
export TARGETS="${TARGETS:-x86_64-unknown-linux-gnu}"
export URL="${URL:-http://127.0.0.1:8000.}"

exec rustup-mirror --upstream-url "$UPSTREAM" \
                   --targets "$TARGETS" \
                   --gc "$GC" \
                   --url "$URL" \
                   --mirror "$TO"
