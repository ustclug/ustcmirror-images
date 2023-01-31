#!/bin/bash

# Migrated to yuki (docker) by @taoky
# Created by @ksqsf
# Based on the original version written by @knight42

# ENVS:
# CRATES_PROXY=
# CRATES_GITMSG=
# CRATES_GITMAIL=
# CRATES_GITNAME=

is_empty() {
    [[ -z $(ls -A "$1" 2>/dev/null) ]]
}

set -e
[[ -n $DEBUG ]] && set -x

CRATES_PROXY="${CRATES_PROXY:-https://crates-io.proxy.ustclug.org/api/v1/crates}"
CRATES_GITMSG="${CRATES_GITMSG:-Redirect to USTC Mirrors}"
CRATES_GITMAIL="${CRATES_GITMAIL:-lug AT ustc.edu.cn}"
CRATES_GITNAME="${CRATES_GITNAME:-mirror}"

ensure_redirect() {
    pushd "$TO"
    if grep -F -q "$CRATES_PROXY" 'config.json'; then
        return
    else
        cat <<EOF > 'config.json'
{
    "dl": "$CRATES_PROXY",
    "api": "https://crates.io/"
}
EOF
        git add config.json
        git -c user.name="$CRATES_GITNAME" -c user.email="$CRATES_GITMAIL" commit -qm "$CRATES_GITMSG"
    fi
    popd
}

# crates.io-index has a custom ensure_redirect logic
# so now we don't use gitsync here.

if ! is_empty "$TO"; then
    cd "$TO"
    git fetch origin
    git reset --hard origin/master
    ensure_redirect
    git repack -adb
    git gc --auto
    git update-server-info
else
    git clone 'https://github.com/rust-lang/crates.io-index.git' "$TO"
    ensure_redirect
fi
