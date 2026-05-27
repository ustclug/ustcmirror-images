#!/bin/bash

set -eu
[[ $DEBUG = true ]] && set -x

INDEX_DIR="${TO%/}/index"
CRATES_DIR="${TO%/}/crates"
STATE_DIR="${TO%/}/state"
export CRATES_PROXY="${CRATES_PROXY:-https://mirrors.ustc.edu.cn/crates.io/crates/{crate}/{crate}-{version}.crate}"

mkdir -p "$INDEX_DIR" "$CRATES_DIR" "$STATE_DIR"

# Reuse the existing crates.io-index image logic, but keep the index checkout
# separate from crate tarballs to avoid unnecessary git and filesystem churn.
TO="$INDEX_DIR" /sync-crates.sh

exec python3 /sync-crates.py \
    --index "$INDEX_DIR" \
    --crates "$CRATES_DIR" \
    --state "$STATE_DIR"
