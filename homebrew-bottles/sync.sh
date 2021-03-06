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

# extract sha256, URL and file name from JSON result
bottles-json < $FORMULA_JSON > $BOTTLES
if [[ $? -ne 0 ]]; then
    echo "[FATAL] json parsing failed."
    exit 4
fi

# JSON API mixing linuxbrew bottles and homebrew bottles
# we need to filtering linux one
if [[ $TARGET_OS == linux ]]; then
	sed -i '/x86_64_linux/!d' $BOTTLES
fi

# GitHub Packages auth info
headers_file=$(mktemp)
cat << EOF > $headers_file
Accept: application/vnd.oci.image.index.v1+json
Authorization: Bearer QQ==
EOF

# parallel downloading
export by_hash=$(realpath $TO/.by-hash)
export by_hash_pattern="./.by-hash/*"
export local_dir=$TO
export enable_urldecode=true
export enable_alternative_path=true
export enable_checksum=true
export CURL_WRAP="$CURL_WRAP --header @$headers_file"
parallel --line-buffer -j $HOMEBREW_BOTTLES_JOBS --pipepart -a $BOTTLES download

# clean up outdated bottles
removal_list=$(mktemp)
cd $local_dir
comm -23 <(find . -type f -not -path "$by_hash_pattern" | sed "s|^./||" | sort) <(awk '{print $3}' $BOTTLES | sort) | tee $removal_list | xargs rm -f
sed 's/^/[INFO] remove /g' $removal_list

# clean empty dir. If enerything work as expect, this command would do nothing
find . -type d -empty -delete

clean_hash_file
