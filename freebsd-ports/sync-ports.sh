#!/usr/bin/env bash

[[ $DEBUG == true ]] && set -x

FBSD_PORTS_INDEX_UPSTREAM=${FBSD_PORTS_INDEX_UPSTREAM:-"https://github.com/freebsd/freebsd-ports.git"}
FBSD_PORTS_DISTFILES_UPSTREAM=${FBSD_PORTS_DISTFILES_UPSTREA:-"http://distcache.freebsd.org/ports-distfiles"}
FBSD_PORTS_JOBS=${FBSD_PORTS_JOBS:-1}
tmpdir=$(mktemp -d)
meta=$(mktemp)
removal_list=$(mktemp)

download_and_check() {
	while read sum repopath; do
		[[ -f $local_dir/$repopath ]] && continue
		curl -m 600 -sSfRL --create-dirs -o $local_dir/$repopath.tmp $remote_url/$repopath
		if [[ $? -ne 0 ]]; then
			echo "[WARN] download failed $remote_url/$repopath"
			rm -f $local_dir/$repopath.tmp
			continue
		fi
		if echo $sum $local_dir/$repopath.tmp | sha256sum -c --quiet --status ; then
			mv $local_dir/$repopath.tmp $local_dir/$repopath
			echo "[INFO] downloaded $remote_url/$repopath"
		else
			echo "[WARN] checksum mismatch $remote_url/$repopath"
			rm -f $local_dir/$repopath.tmp
		fi
	done
}

mkdir -p $TO/distfiles

# update meta
TO=$TO/ports.git GITSYNC_URL=$FBSD_PORTS_INDEX_UPSTREAM /sync.sh
if [[ $? -ne 0 ]]; then
	echo "[FATAL] download meta-data failed."
	exit 1
fi

# prepare meta list
cd $tmpdir
git -C $TO/ports.git archive HEAD | tar -xf -
find . -name distinfo -print0 | xargs -0 cat | awk '-F[() ]' '/^SHA256/ {print $NF,$3}' | sort -k 2 | uniq > $meta

# clean unfinished downloads
find $TO/distfiles -name '*.tmp' -delete

# get distfile
export PARALLEL_SHELL=/bin/bash
export -f download_and_check
remote_url=$FBSD_PORTS_DISTFILES_UPSTREAM local_dir=$TO/distfiles parallel -j $FBSD_PORTS_JOBS --pipepart -a $meta download_and_check

# generate index arvhive
git -C $TO/ports.git archive --format=tar.gz -o $TO/ports.tar.gz HEAD

# remove old distfile
comm -23 <(cd $TO/distfiles; find . -type f | sed 's/^\.\///g' | sort) <(awk '{print $2}' $meta) | tee $removal_list | xargs rm -f 
sed 's/^/[INFO] remove /g' $removal_list 

# fix dir mode
find $TO -type d -print0 | xargs -0 chmod 755

# cleam temp file
rm -f $meta $removal_list 
rm -r $tmpdir

