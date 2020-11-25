#!/usr/bin/env bash

[[ $DEBUG == true ]] && set -x

FBSD_PORTS_INDEX_UPSTREAM=${FBSD_PORTS_INDEX_UPSTREAM:-"https://github.com/freebsd/freebsd-ports.git"}
FBSD_PORTS_DISTFILES_UPSTREAM=${FBSD_PORTS_DISTFILES_UPSTREAM:-"http://distcache.freebsd.org/ports-distfiles"}
FBSD_PORTS_JOBS=${FBSD_PORTS_JOBS:-1}
tmpdir=$(mktemp -d)
meta=$(mktemp)
removal_list=$(mktemp)
export BY_HASH=$(realpath $TO/.by-hash)

is_ipv6() {
	# string contains a colon
	[[ $1 =~ .*: ]]
}

if [[ -n $BIND_ADDRESS ]]; then
	if is_ipv6 "$BIND_ADDRESS"; then
		CURL_WRAP="curl -6 --interface $BIND_ADDRESS"
	else
		CURL_WRAP="curl -4 --interface $BIND_ADDRESS"
	fi
else
	CURL_WRAP="curl"
fi
export CURL_WRAP

download_and_check() {
	cd $BY_HASH
	while read sum repopath; do
		if [[ -f $sum ]]; then
			if [[ ! $sum -ef $local_dir/$repopath ]]; then
				ln -f $sum $local_dir/$repopath
			fi
		else
			echo "[INFO] download $remote_url/$repopath"
			$CURL_WRAP -m 600 -sSfRL -o $sum.tmp $remote_url/$repopath
			if [[ $? -ne 0 ]]; then
				echo "[WARN] download failed $remote_url/$repopath"
				rm -f $sum.tmp
				continue
			fi

			if echo $sum $sum.tmp | sha256sum -c --quiet --status ; then
				mv $sum.tmp $sum
				ln -f $sum $local_dir/$repopath
			else
				echo "[WARN] checksum mismatch $remote_url/$repopath"
				rm -f $sum.tmp
			fi
		fi
	done
}

mkdir -p $TO/distfiles
mkdir -p $BY_HASH || return 1

# update meta
TO=$TO/ports.git GITSYNC_URL=$FBSD_PORTS_INDEX_UPSTREAM /sync.sh
if [[ $? -ne 0 ]]; then
	echo "[FATAL] download meta-data failed."
	exit 1
fi

# prepare meta list
cd $tmpdir
git -C $TO/ports.git archive HEAD | tar -xf -
find . -name distinfo -print0 | parallel -j 8 -0 --xargs cat | awk '-F[() ]' '/^SHA256/ {print $NF,$3}' | sort -k 2 | uniq > $meta

# clean unfinished downloads
find $TO/distfiles -name '*.tmp' -delete

# get distfile
export PARALLEL_SHELL=/bin/bash
export -f download_and_check
remote_url=$FBSD_PORTS_DISTFILES_UPSTREAM local_dir=$TO/distfiles parallel --line-buffer -j $FBSD_PORTS_JOBS --pipepart -a $meta download_and_check

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

# purge old hash files
find $BY_HASH -type f -links 1 -print0 | xargs -0 rm -f
