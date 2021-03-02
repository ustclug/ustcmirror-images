#!/usr/bin/env bash

[[ $DEBUG == true ]] && set -x

urldecode() {
	: "${*//+/ }"
	echo -e "${_//\%/\\x}"
}
export -f urldecode

download() {
	if [[ $enable_checksum == "true" ]]; then
		download_with_checksum
	elif [[ $enable_mtime == "true" ]]; then
		download_with_mtime
	else
		download_with_checksum
	fi
}
export -f download

download_with_checksum() {
	local local_dir=${local_dir:="$TO"}
	local remote_url=${remote_url:=""}
	local by_hash=${by_hash:-"$local_dir/.by-hash"}
	curl_init
	mkdir -p $by_hash || return 1
	while read checksum path; do
		local p=$(urldecode $local_dir/$path)
		local c=$by_hash/$checksum
		local url=$remote_url/$path
		if [[ -f $c ]]; then
			if [[ ! $c -ef $p ]]; then
				mkdir -p $(dirname $p)
				ln -f $c $p
			fi
		else
			echo "[INFO] download $url"
			$CURL_WRAP -m 600 -sSfRL --create-dirs -o $c.tmp $url
			if [[ $? -ne 0 ]]; then
				echo "[WARN] download failed $url"
				rm -f $c.tmp
				continue
			fi

			if echo $checksum $c.tmp | sha256sum -c --quiet --status ; then
				mv $c.tmp $c
				mkdir -p $(dirname $p)
				ln -f $c $p
			else
				echo "[WARN] checksum mismatch $url"
				rm -f $c.tmp
			fi
		fi
	done
}
export -f download_with_checksum

download_with_mtime() {
	local local_dir=${local_dir:="$TO"}
	local remote_url=${remote_url:=""}
	local fail_to_exit=${fail_to_exit:="false"}
	curl_init
	[[ $DEBUG == true  ]] && echo "[DEBUG] fail_to_exit=${fail_to_exit}"
	while read path; do
		local p=$(urldecode $local_dir/$path)
		local url=$remote_url/$path
		if [[ -f $p ]]; then
			local remote_mtime=$($CURL_WRAP -sLI $url | grep -oP '(?<=^Last-Modified: ).+$')
			local remote_mtime=$(date --date="$remote_mtime" +%s)
			local local_mtime=$(stat -c %Y "$p")
			if [[ $local_mtime -eq $remote_mtime ]] ; then
				echo "[INFO] skip $url"
				continue
			fi
		fi
		$CURL_WRAP -m 600 -sSfRL --create-dirs -o $p $url
		if [[ $? -ne 0 ]]; then
			echo "[WARN] download failed $url"
			[[ $fail_to_exit != false ]] && return 1
		else
			echo "[INFO] downloaded $url"
		fi
	done
}
export -f download_with_mtime


is_ipv6() {
	# string contains a colon
	[[ $1 =~ .*: ]]
}
export -f is_ipv6

curl_init() {
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
}
export -f curl_init


clean_hash_file() {
	# purge old hash files
	echo "[INFO] clean hash files"
	find $by_hash -type f -links 1 -delete
}
export -f clean_hash_file
