#!/usr/bin/env bash

[[ $DEBUG == true ]] && set -x

source /curl-helper.sh

FBSD_PKG_UPSTREAM=${FBSD_PKG_UPSTREAM:-"http://pkg.freebsd.org"}
FBSD_PKG_EXCLUDE=${FBSD_PKG_EXCLUDE:-"^FreeBSD:([0-9]+:(?!amd64|i386|aarch64)[a-z0-9]+$)"}
FBSD_PKG_JOBS=${FBSD_PKG_JOBS:-1}
FBSD_PLATFORMS=$(mktemp)
export PARALLEL_SHELL=/bin/bash

# for curl-helper
export by_hash=$(realpath $TO/.by-hash)

EXIT_CODE=0

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
	# manually include meta-data files to avoid OOM (tmpfs)
	rsync -a --include=Latest --include=data.* --include=meta --include=meta.* --include=packagesite.* --exclude=* $basedir/ $tmpdir/

	# get meta-data
	export remote_url=$baseurl
	export local_dir=$tmpdir
	enable_mtime=true fail_to_exit=false download <<<"$(echo digests.txz meta.txz meta.conf meta.pkg packagesite.txz packagesite.tzst data.pkg data.txz data.tzst | tr ' ' '\n')"
	enable_mtime=true fail_to_exit=true  download <<<"$(echo meta packagesite.pkg | tr ' ' '\n')"

	if [[ $? -ne 0 ]]; then
		echo "[FATAL] download meta-data failed."
		EXIT_CODE=$((EXIT_CODE + 1))
		return 1
	fi

	# get pkg software
	enable_mtime=true fail_to_exit=false download <<<"$(echo Latest/{pkg-devel.txz,pkg.txz,pkg.txz.sig} | tr ' ' '\n')"
	enable_mtime=true fail_to_exit=false download <<<"$(echo Latest/{pkg-devel.pkg,pkg.pkg,pkg.pkg.sig} | tr ' ' '\n')"

	# get packages
	tar -C $tmpdir -xJf $tmpdir/packagesite.pkg packagesite.yaml
	if [[ $? -ne 0 ]]; then
		echo '[WARN] xz failed, trying zstd...'
		tar -C $tmpdir --zstd -xf $tmpdir/packagesite.pkg packagesite.yaml
		if [[ $? -ne 0 ]]; then
			echo '[FATAL] zstd packagesite.pkg failed.'
			EXIT_CODE=$((EXIT_CODE + 1))
			return 1
		fi
	fi
	jq -r '"\(.sum) \(.repopath)"' $tmpdir/packagesite.yaml | sort -k2 > $meta
	rm -f $tmpdir/packagesite.yaml
	export local_dir=$basedir
	enable_checksum=true parallel --line-buffer -j $FBSD_PKG_JOBS --pipepart -a $meta download

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

curl_init

echo "[INFO] getting version list..."
$CURL_WRAP -sSL $FBSD_PKG_UPSTREAM | grep -oP 'FreeBSD:[0-9]+:[a-z0-9]+' | grep -vP $FBSD_PKG_EXCLUDE | sort -t : -rnk 2 | uniq | tee $FBSD_PLATFORMS
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
	echo "[FATAL] get version list from $FBSD_PKG_UPSTREAM failed."
	exit 1
fi

while read platform; do
	echo "[INFO] getting channel list of $platform..."
	channels=$($CURL_WRAP -sSL $FBSD_PKG_UPSTREAM/$platform | grep -oP 'latest|quarterly|base_[a-z0-9_]+|kmods_[a-z0-9_]+' | sort -t : -rnk 2 | uniq)
 	echo $channels
	for channel in $channels; do
		if $CURL_WRAP -sLIf -o /dev/null $FBSD_PKG_UPSTREAM/$platform/$channel/packagesite.pkg; then
			channel_sync $FBSD_PKG_UPSTREAM/$platform/$channel $TO/$platform/$channel
		fi
	done
	echo "[INFO] finished $platform, doing GC to free some disk space..."
	clean_hash_file
done < $FBSD_PLATFORMS

find $TO -type d -print0 | xargs -0 chmod 755

rm $FBSD_PLATFORMS

exit $EXIT_CODE
