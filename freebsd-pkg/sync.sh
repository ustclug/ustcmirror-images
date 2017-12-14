#!/usr/bin/env bash

[[ $DEBUG == true ]] && set -x

FBSD_PKG_UPSTREAM=${FBSD_PKG_UPSTREAM:-"http://pkg.freebsd.org"}
FBSD_PKG_JOBS=${FBSD_PKG_JOBS:-1}
FBSD_PLATFORMS=$(mktemp)

export PARALLEL_SHELL=/bin/bash

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
export -f download_and_check

download_or_fail() {
	local fail_to_exit=$1; shift
	for repopath in "$@"; do
		if [[ -f $local_dir/$repopath ]]; then
			local remote_mtime=$(curl -sI $remote_url/$repopath | grep -oP '(?<=^Last-Modified: ).+$')
			local remote_mtime=$(date --date="$remote_mtime" +%s)
			local local_mtime=$(stat -c %Y "$local_dir/$repopath")
			if [[ $local_mtime -eq $remote_mtime ]] ; then
				[[ $DEBUG == true ]] && echo "[DEBUG] not modified and skip $remote_url/$repopath"
				continue
			fi
		fi
		curl -m 600 -sSfRL --create-dirs -o $local_dir/$repopath $remote_url/$repopath
		if [[ $? -ne 0 ]]; then
			echo "[WARN] download failed $remote_url/$repopath"
			[[ $fail_to_exit != false ]] && return 1
		else
			echo "[INFO] downloaded $remote_url/$repopath"
		fi
	done
}

channel_sync() {
	local baseurl=$1
	local basedir=$2
	local tmpdir=$(mktemp -d)
	local meta=$(mktemp)

	echo "[INFO] syncing $baseurl"

	# clean unfinished downloads
	find $basedir -name '*.tmp' -delete

	# restore old meta-data to $tmpdir
	rsync -a --exclude=/All $basedir/ $tmpdir/

	# get meta-data
	export remote_url=$baseurl
	export local_dir=$tmpdir
	download_or_fail digests.txz meta.txz packagesite.txz
	if [[ $? -ne 0 ]]; then
		echo "[FATAL] download meta-data failed."
		return 1
	fi

	# get pkg software
	download_or_fail Latest/{pkg-devel.txz,pkg.txz,pkg.txz.sig}

	# get packages
	tar -C $tmpdir -xJf $tmpdir/packagesite.txz packagesite.yaml 
	if [[ $? -ne 0 ]]; then
		echo '[FATAL] unzip packagesite.txz failed.'
		return 1
	fi
	jq -r '"\(.sum) \(.repopath)"' $tmpdir/packagesite.yaml > $meta
	export local_dir=$basedir
	parallel -j $FBSD_PKG_JOBS --pipepart -a $meta download_and_check

	# update meta-data
	rsync -a $tmpdir/ $basedir/

	# purge old packages
	local removal_list=$(mktemp)
	comm -23 <(ls $basedir/All | sort) <(awk '-F[ /]' '{print $3}' $meta | sort) | sed "s/^/${basedir//\//\\/}\\/All\\//g" | tee $removal_list | xargs rm -f 
	sed 's/^/[INFO] remove /g' $removal_list 

	# clean temp file or dir
	rm -f $meta $removal_list
	rm -r $tmpdir

	echo "[INFO] sync finished $baseurl"
}

mkdir -p ~/.parallel
touch ~/.parallel/will-cite

echo "[INFO] getting version list..."
curl -sSL $FBSD_PKG_UPSTREAM | grep -oP 'FreeBSD:[0-9]+:[a-z0-9]+' | sort -t : -rnk 2 | uniq | tee $FBSD_PLATFORMS

while read platform; do
	mkdir -p $TO/$platform/latest
	channel_sync $FBSD_PKG_UPSTREAM/$platform/latest $TO/$platform/latest
done < $FBSD_PLATFORMS

find $TO -type d -print0 | xargs -0 chmod 755

rm $FBSD_PLATFORMS
