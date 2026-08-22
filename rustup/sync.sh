#!/bin/bash

set -eu
[[ $DEBUG = true ]] && set -x

echo "Running script"

export UPSTREAM="${UPSTREAM:-https://static.rust-lang.org/}"
export GC="${GC:-1}"
export TARGETS="${TARGETS:-x86_64-unknown-linux-gnu}"
export TIER1_ONLY="${TIER1_ONLY:-false}"
export CHANNELS="${CHANNELS:-stable,beta,nightly}"
export URL="${URL:-http://127.0.0.1:8000.}"

if [[ $TIER1_ONLY = true ]]; then
    TARGETS="aarch64-apple-darwin,aarch64-pc-windows-msvc,aarch64-unknown-linux-gnu,i686-pc-windows-gnu,i686-pc-windows-msvc,i686-unknown-linux-gnu,x86_64-apple-darwin,x86_64-pc-windows-gnu,x86_64-pc-windows-msvc,x86_64-unknown-linux-gnu"
fi

cd "$TO"

exec rustup-mirror --upstream-url "$UPSTREAM" \
                   --targets "$TARGETS" \
                   --channels "$CHANNELS" \
                   --gc "$GC" \
                   --url "$URL" \
                   --mirror "$TO" \
                   --orig "$TO/orig"
