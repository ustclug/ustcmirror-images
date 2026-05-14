#!/bin/bash

# Migrated to yuki (docker) by @taoky
# Created by @ksqsf
# Based on the original version written by @knight42

set -eu
[[ $DEBUG = true ]] && set -x

export GITSYNC_URL="${GITSYNC_URL:-https://github.com/rust-lang/crates.io-index.git}"
export GITSYNC_CHECKOUT=true
export GITSYNC_BITMAP=true
export GITSYNC_GEOMETRIC="${GITSYNC_GEOMETRIC:-${GEOMETRIC_REPACK:-false}}"
export GITSYNC_POST_FETCH_HOOK=/crates-hook.sh

exec /sync.sh
