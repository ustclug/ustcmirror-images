#!/usr/bin/env bash

HOMEBREW_BOTTLES_JOBS=${HOMEBREW_BOTTLES_JOBS:-1}
TARGET_OS=${TARGET_OS:-mac}

source /curl-helper.sh

FORMULA_JSON=$(mktemp)
BOTTLES=$(mktemp)
if [[ $TARGET_OS == mac ]]; then
	URL_JSON=https://formulae.brew.sh/api/formula.json
elif [[ $TARGET_OS == linux ]]; then
	URL_JSON=https://formulae.brew.sh/api/formula-linux.json
else
	echo "[ERROR] unsupported target."
	exit 2
fi

curl_init

$CURL_WRAP -sSL -o "$FORMULA_JSON" "$URL_JSON"
if [[ $? -ne 0 ]]; then
    echo "[FATAL] download meta-data failed."
    exit 3
fi
jq -r ' .[].bottle | .[].files | .[] | "\(.sha256) \(.url)"' < $FORMULA_JSON > $BOTTLES
URL_BASE=$(grep -oP 'https?://.+(?=/bottles/[^/]+.gz$)' $BOTTLES | uniq)
if [[ -z $URL_BASE ]]; then
    echo "[FATAL] unexpected URL format, please report."
    exit 4
elif [[ `wc -l <<<$URL_BASE` != 1 ]]; then
    echo "[WARN] inconsistent URL base."
fi
HOMEBREW_BOTTLE_DOMAIN=${HOMEBREW_BOTTLE_DOMAIN:-$(head -n 1 <<<$URL_BASE)}

# drop URL common base, leave only "bottles/*.tar.gz"
sed -i 's|https\?://.\+/\(bottles/.\+\.gz\)$|\1|' $BOTTLES

# JSON API mixing linuxbrew bottles and homebrew bottles
# we need to filtering linuxbrew one
if [[ $TARGET_OS == linux ]]; then
	sed -i '/x86_64_linux/!d' $BOTTLES
fi

export by_hash=$(realpath $TO/.by-hash)
export by_hash_pattern="./.by-hash/*"
export remote_url=$HOMEBREW_BOTTLE_DOMAIN
export local_dir=$TO
enable_checksum=true parallel --line-buffer -j $HOMEBREW_BOTTLES_JOBS --pipepart -a $BOTTLES download

# urldecode
gawk -i inplace  -niord '{printf RT?$0chr("0x"substr(RT,2)):$0}' RS=%.. $BOTTLES

removal_list=$(mktemp)
cd $local_dir
comm -23 <(find . -type f -not -path "$by_hash_pattern" | sed "s|^./||" | sort) <(awk '{print $2}' $BOTTLES | sort) | tee $removal_list | xargs rm -f
sed 's/^/[INFO] remove /g' $removal_list

clean_hash_file
