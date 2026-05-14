#!/bin/bash

# ENVS:
# CRATES_PROXY=
# CRATES_GITMSG=
# CRATES_GITMAIL=
# CRATES_GITNAME=

set -eu
[[ $DEBUG = true ]] && set -x

CRATES_PROXY="${CRATES_PROXY:-https://crates-io.proxy.ustclug.org/api/v1/crates}"
CRATES_GITMSG="${CRATES_GITMSG:-Redirect to USTC Mirrors}"
CRATES_GITMAIL="${CRATES_GITMAIL:-lug AT ustc.edu.cn}"
CRATES_GITNAME="${CRATES_GITNAME:-mirror}"

cd "$TO"

if grep -F -q "$CRATES_PROXY" config.json; then
    exit 0
fi

cat <<EOF > config.json
{
    "dl": "$CRATES_PROXY",
    "api": "https://crates.io/"
}
EOF

git add config.json
git -c user.name="$CRATES_GITNAME" -c user.email="$CRATES_GITMAIL" commit -qm "$CRATES_GITMSG"
