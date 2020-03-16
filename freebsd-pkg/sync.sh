#!/usr/bin/env bash

[[ $DEBUG == true ]] && set -x

FBSD_PKG_UPSTREAM=${FBSD_PKG_UPSTREAM:-"http://pkg.freebsd.org"}
FBSD_PKG_EXCLUDE=${FBSD_PKG_EXCLUDE:-"^FreeBSD:[89]:"}
FBSD_PKG_JOBS=${FBSD_PKG_JOBS:-1}
FBSD_PLATFORMS=$(mktemp)
export BY_HASH=$(realpath $TO/.by-hash)
export PARALLEL_SHELL=/bin/bash

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
export -f download_and_check

download_or_fail() {
	local fail_to_exit=$1; shift
	for repopath in "$@"; do
		if [[ -f $local_dir/$repopath ]]; then
			local remote_mtime=$($CURL_WRAP -sI $remote_url/$repopath | grep -oP '(?<=^Last-Modified: ).+$')
			local remote_mtime=$(date --date="$remote_mtime" +%s)
			local local_mtime=$(stat -c %Y "$local_dir/$repopath")
			if [[ $local_mtime -eq $remote_mtime ]] ; then
				[[ $DEBUG == true ]] && echo "[DEBUG] not modified and skip $remote_url/$repopath"
				continue
			fi
		fi
		$CURL_WRAP -m 600 -sSfRL --create-dirs -o $local_dir/$repopath $remote_url/$repopath
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

	mkdir -p $basedir/All
	cd $basedir

	# clean unfinished downloads
	find $basedir -name '*.tmp' -delete

	# restore old meta-data to $tmpdir
	rsync -a --exclude=/All $basedir/ $tmpdir/

	# get meta-data
	export remote_url=$baseurl
	export local_dir=$tmpdir
	download_or_fail true digests.txz meta.txz packagesite.txz
	if [[ $? -ne 0 ]]; then
		echo "[FATAL] download meta-data failed."
		return 1
	fi

	# get pkg software
	download_or_fail false Latest/{pkg-devel.txz,pkg.txz,pkg.txz.sig}

	# get packages
	tar -C $tmpdir -xJf $tmpdir/packagesite.txz packagesite.yaml
	if [[ $? -ne 0 ]]; then
		echo '[FATAL] unzip packagesite.txz failed.'
		return 1
	fi
	jq -r '"\(.sum) \(.repopath)"' $tmpdir/packagesite.yaml | sort -k2 > $meta
	rm -f $tmpdir/packagesite.yaml
	export local_dir=$basedir
	parallel --line-buffer -j $FBSD_PKG_JOBS --pipepart -a $meta download_and_check

	# update meta-data
	rsync -a $tmpdir/ $basedir/

	# purge old packages
	local removal_list=$(mktemp)
	comm -23 <(find All -type f | sort) <(awk '{print $2}' $meta) | tee $removal_list | xargs rm -f
	sed 's/^/[INFO] remove /g' $removal_list

	# clean temp file or dir
	rm -f $meta $removal_list
	rm -r $tmpdir

	echo "[INFO] sync finished $baseurl"
}

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

mkdir -p $BY_HASH || return 1

echo "[INFO] getting version list..."
$CURL_WRAP -sSL $FBSD_PKG_UPSTREAM | grep -oP 'FreeBSD:[0-9]+:[a-z0-9]+' | grep -vP $FBSD_PKG_EXCLUDE | sort -t : -rnk 2 | uniq | tee $FBSD_PLATFORMS

while read platform; do
	channel_sync $FBSD_PKG_UPSTREAM/$platform/latest $TO/$platform/latest
	if $CURL_WRAP -sLIf -o /dev/null $FBSD_PKG_UPSTREAM/$platform/quarterly/packagesite.txz; then
		channel_sync $FBSD_PKG_UPSTREAM/$platform/quarterly $TO/$platform/quarterly
	fi
done < $FBSD_PLATFORMS

find $TO -type d -print0 | xargs -0 chmod 755

rm $FBSD_PLATFORMS

# purge old hash files
echo "[INFO] clean hash files"
find $BY_HASH -type f -links 1 -delete
