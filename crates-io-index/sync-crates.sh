#!/bin/bash

# Migrated to yuki (docker) by @taoky
# Created by @ksqsf
# Based on the original version written by @knight42

set -eu
[[ $DEBUG = true ]] && set -x

GITSYNC_URL="${GITSYNC_URL:-https://github.com/rust-lang/crates.io-index.git}"
GITSYNC_BRANCH="${GITSYNC_BRANCH:-master:master}"
GITSYNC_CHECKOUT=true
GITSYNC_BITMAP=true
GITSYNC_GEOMETRIC="${GITSYNC_GEOMETRIC:-${GEOMETRIC_REPACK:-false}}"
GITSYNC_POST_FETCH_HOOK=/crates-hook.sh

exec /sync.sh
