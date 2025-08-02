#!/bin/bash

set -eu
[[ $DEBUG = true ]] && set -x

echo "Running script"

export UPSTREAM_URL="${UPSTREAM_URL:-https://static.rust-lang.org/}"
export GARBAGE_COLLECT_DAYS="${GARBAGE_COLLECT_DAYS:-1}"
export MIRROR_TARGETS="${MIRROR_TARGETS:-x86_64-unknown-linux-gnu}"
export SERVER_URL="${SERVER_URL:-http://127.0.0.1:8000}"

rustup-mirror --upstream-url "$UPSTREAM_URL" \
              --targets "$MIRROR_TARGETS" \
	      --gc "$GARBAGE_COLLECT_DAYS" \
	      --url "$SERVER_URL" \
	      --mirror "$TO"


