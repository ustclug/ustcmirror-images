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

export PYTHONUNBUFFERED=1
# https://gerrit.googlesource.com/git-repo/+/a6c52f566acfbff5b0f37158c0d33adf05d250e5 (2022/11/03) changes behavior of tracing
# from directly outputting to storing to .repo/TRACE_FILE
repo --trace --trace-to-stderr sync || repo_ret=$?
rm -f "$TO"/.repo/TRACE_FILE

if [[ ! $repo_ret == 0 ]]; then
    # Don't let syncing failure stop repacking
    echo "[warn]: repo sync returns an unzero exit code: $repo_ret"
fi
echo "start repacking git objects"
find -name "*.git" -exec bash -c "pushd {} && git repack -abd" \;

exit $repo_ret
