#!/usr/bin/env bash

HOMEBREW_BOTTLES_JOBS=${HOMEBREW_BOTTLES_JOBS:-1}

source /curl-helper.sh

FORMULA_JSON="$TO/api/formula.json"
CASK_JSON="$TO/api/cask.json"
mkdir -p "$TO/api"
mkdir -p "$TO/api/formula"
mkdir -p "$TO/api/cask"

BOTTLES=$(mktemp)
FORMULA_URL_JSON=https://formulae.brew.sh/api/formula.json
CASK_URL_JSON=https://formulae.brew.sh/api/cask.json

curl_init

# Step 1: Download new API jsons and extract
$CURL_WRAP -sSL -o "$FORMULA_JSON".tmp "$FORMULA_URL_JSON"
if [[ $? -ne 0 ]]; then
	echo "[FATAL] download formula meta-data failed."
	exit 2
fi
$CURL_WRAP -sSL -o "$CASK_JSON".tmp "$CASK_URL_JSON"
if [[ $? -ne 0 ]]; then
	echo "[FATAL] download cask meta-data failed."
	exit 3
fi
bottles-json --mode extract-json --type formula --folder "$TO/api/formula" < "$FORMULA_JSON".tmp
if [[ $? -ne 0 ]]; then
    echo "[FATAL] formula API json extracting failed."
    exit 5
fi
bottles-json --mode extract-json --type cask --folder "$TO/api/cask" < "$CASK_JSON".tmp
if [[ $? -ne 0 ]]; then
	echo "[FATAL] cask API json extracting failed."
	exit 6
fi
mv "$FORMULA_JSON".tmp "$FORMULA_JSON"
mv "$CASK_JSON".tmp "$CASK_JSON"

# Step 2: Download bottles (formula only)
# extract sha256, URL and file name from JSON result
bottles-json < $FORMULA_JSON > $BOTTLES
if [[ $? -ne 0 ]]; then
    echo "[FATAL] json parsing failed."
    exit 4
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
comm -23 <(find . -type f -not -path "$by_hash_pattern" -not -path "./api/*" | sed "s|^./||" | sort) <(awk '{print $3}' $BOTTLES | sort) | tee $removal_list | xargs rm -f
sed 's/^/[INFO] remove /g' $removal_list

# clean empty dir. If enerything work as expect, this command would do nothing
find . -type d -empty -delete

clean_hash_file
