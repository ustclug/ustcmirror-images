#!/bin/bash
set -e
set -o pipefail

function remove_broken() {
	interval=$1
	interval_file="/tmp/hackage_lastcheck"
	now=`date +%s`

	if [[ -f ${interval_file} ]]; then
		lastcheck=`cat ${interval_file}`
		((between = now - lastcheck))
		if ((between < interval)); then
			echo "skip checking"
			return 0
		fi
	fi
	echo "start checking"

	mkdir -p "${TO}/package"
	cd "${TO}/package"

	for line in `ls`; do
        echo "$line"
		tar -tzf $line &>/dev/null || (printf 'FAIL %s\n' "$line"; rm $line) # && echo "OK"
	done

	echo `date +%s` > $interval_file
}

function must_download() {
	src=$1
	dst=$2
	while true; do
		echo "downloading: $name"
		wget "$src" -O "$dst" &>/dev/null
		tar -tzf package/$name >/dev/null || rm package/$name && break
	done
	return 0
}

function hackage_mirror() {
	local_pklist="/tmp/hackage_local_pklist_$$.list"
	remote_pklist="/tmp/hackage_remote_pklist_$$.list"

	cd ${TO}
	mkdir -p package

	echo "Downloading index..."
	rm index.tar.gz || true
	wget "${HACKAGE_BASE_URL}/packages/index.tar.gz" -O index.tar.gz &> /dev/null

    echo `ls`
	echo "building remote package list"
	tar -ztf index.tar.gz | (cut -d/ -f 1,2 2>/dev/null) | sed 's|/|-|' > $remote_pklist

	echo "building local package list"
	local tmp
	tmp=(package/*)
	tmp=(${tmp[@]#package/})
	printf '%s\n' "${tmp[@]%.tar.gz}" > "${local_pklist}"


	echo "building download list"
	# substract local list from remote list
	# this cannot use pipe, or the `wait` afterwards cannot wait
	# because pipe spawns a subshell
	while read pk; do
		# ignore package suffix "preferred-versions"
		# echo $pk
		if [[ $pk = *-preferred-versions ]]; then
			continue
		fi
		# limit concurrent level
		bgcount=`jobs | wc -l`
		while [[ $bgcount -ge 5 ]]; do
			sleep 0.5
			bgcount=`jobs | wc -l`
		done

		name="$pk.tar.gz"
		if [ ! -a package/$name ]; then
			must_download "${HACKAGE_BASE_URL}/package/$pk/$name" "package/$name" &
		else
			echo "skip existed: $name"
		fi
	done < <(comm <(sort $remote_pklist) <(sort $local_pklist) -23)

	wait

	# delete redundanty files
	comm <(sort $remote_pklist) <(sort $local_pklist) -13 | while read pk; do
		if [[ $pk == "preferred-versions" ]]; then
			continue
		fi
		name="${pk}.tar.gz"
		echo "deleting ${name}"
		rm "package/$name"
	done

	cp index.tar.gz 00-index.tar.gz
}

function cleanup () {
	echo "cleaning up"
	[[ ! -z $local_pklist ]] && (rm $local_pklist $remote_pklist ; true)
}

trap cleanup EXIT
remove_broken 86400
hackage_mirror
