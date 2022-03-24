#!/bin/bash

set -e
[[ -n $DEBUG ]] && set -x

UPSTREAM="${UPSTREAM:-https://android.googlesource.com/mirror/manifest}"

PATH=/usr/local/bin:$PATH

cd "$TO"

# Check if repo has been initialized
if [[ ! -d "$TO"/.repo ]]; then
    echo "initalizing repo"
    repo init -u "$UPSTREAM" --mirror
fi

# Now start syncing
echo "start repo sync"
repo_ret=0
# Don't let syncing failure stop repacking
repo --trace sync || repo_ret=$?
if [[ ! $repo_ret == 0 ]]; then
    echo "[warn]: repo sync returns an unzero exit code: $repo_ret"
fi
echo "start repacking git objects"
find -name "*.git" -exec bash -c "pushd {} && git repack -abd" \;

exit $repo_ret
