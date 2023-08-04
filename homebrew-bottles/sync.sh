#!/usr/bin/env bash

HOMEBREW_BOTTLES_JOBS=${HOMEBREW_BOTTLES_JOBS:-1}

source /curl-helper.sh

mkdir -p "$TO/api"
mkdir -p "$TO/api/formula"
mkdir -p "$TO/api/cask"

BOTTLES=$(mktemp)

curl_init

# Step 1: Download new API jsons and extract

# 2 special jsons for further processing
FORMULA_JSON="$TO/api/formula.json"
CASK_JSON="$TO/api/cask.json"

FILES=(
	"formula.json"
	"cask.json"
	"formula.jws.json"
	"cask.jws.json"
	"formula_tap_migrations.jws.json"
	"cask_tap_migrations.jws.json"
)
URL_BASE="https://formulae.brew.sh/api"

for file in "${FILES[@]}"; do
	$CURL_WRAP --compressed -sSL -o "$TO/api/$file".tmp "$URL_BASE/$file"
	if [[ $? -ne 0 ]]; then
		echo "[FATAL] download $file meta-data failed."
		exit 2
	fi
	mv "$TO/api/$file".tmp "$TO/api/$file"
	# create gz files to save bandwidth (with nginx gzip_static)
	gzip --keep --force "$TO/api/$file"
done

bottles-json --mode extract-json --type formula --folder "$TO/api/formula" < "$FORMULA_JSON"
if [[ $? -ne 0 ]]; then
    echo "[FATAL] formula API json extracting failed."
    exit 5
fi
bottles-json --mode extract-json --type cask --folder "$TO/api/cask" < "$CASK_JSON"
if [[ $? -ne 0 ]]; then
	echo "[FATAL] cask API json extracting failed."
	exit 6
fi

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
