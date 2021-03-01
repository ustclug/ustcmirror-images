#!/usr/bin/env bash

HOMEBREW_BOTTLE_JOBS=${HOMEBREW_BOTTLES_JOBS:-1}
TARGET_OS=${TARGET_OS:-mac}

source /curl-helper.sh

FORMULA_JSON=$(mktemp)
BOTTLES=$(mktemp)
if [[ $TARGET_OS == mac ]]; then
	URL_BASE=https://homebrew.bintray.com
	URL_JSON=https://formulae.brew.sh/api/formula.json
elif [[ $TARGET_OS == linux ]]; then
	URL_BASE=https://linuxbrew.bintray.com
	URL_JSON=https://formulae.brew.sh/api/formula-linux.json
else
	echo "unsupported target"
	exit 1
fi

curl_init

$CURL_WRAP -sSL -o "$FORMULA_JSON" "$URL_JSON"
if [[ $? -ne 0 ]]; then
    echo "[FATAL] download meta-data failed."
    exit 1
fi
jq -r ' .[].bottle | .[].files | .[] | "\(.sha256) \(.url)"' < $FORMULA_JSON > $BOTTLES
sed -i "s|$URL_BASE/||" $BOTTLES
gawk -i inplace  -niord '{printf RT?$0chr("0x"substr(RT,2)):$0}' RS=%.. $BOTTLES #urldecode

if [[ $TARGET_OS == linux ]]; then
	sed -i '/x86_64_linux/!d' $BOTTLES
fi

export by_hash=$(realpath $TO/.by-hash)
export by_hash_pattern="./.by-hash/*"
export remote_url=$URL_BASE
export local_dir=$TO
enable_checksum=true parallel --line-buffer -j $HOMEBREW_BOTTLE_JOBS --pipepart -a $BOTTLES download

removal_list=$(mktemp)
cd $local_dir
comm -23 <(find . -type f -not -path "$by_hash_pattern" | sed "s|^./||" | sort) <(awk '{print $2}' $BOTTLES | sort) | tee $removal_list | xargs rm -f
sed 's/^/[INFO] remove /g' $removal_list

clean_hash_file
