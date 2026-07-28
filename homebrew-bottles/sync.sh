#!/usr/bin/env bash

HOMEBREW_BOTTLES_JOBS=${HOMEBREW_BOTTLES_JOBS:-1}

source /curl-helper.sh

mkdir -p "$TO/api"
mkdir -p "$TO/api/formula"
mkdir -p "$TO/api/cask"
mkdir -p "$TO/api/cask-source"
mkdir -p "$TO/api/internal"

BOTTLES=$(mktemp)
CASK_SOURCES=$(mktemp)

BOTTLES_BIND_ADDRESS="$BIND_ADDRESS"

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
	"internal/executables.txt"
)
URL_BASE="https://formulae.brew.sh/api"

if [ -n "$BREW_SH_BIND_ADDRESS" ]; then
    BIND_ADDRESS="$BREW_SH_BIND_ADDRESS"
fi

curl_init

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

# Download internal/packages.<tag>.jws.json for all bottle tags
# Extract tag list dynamically from formula.json bottle data
BOTTLE_TAGS=$(jq -r '[.[].bottle.stable.files | select(. != null) | keys[] | select(. != "all")] | unique | .[]' "$FORMULA_JSON")
for tag in $BOTTLE_TAGS; do
	file="internal/packages.${tag}.jws.json"
	$CURL_WRAP --compressed -sSL -o "$TO/api/$file".tmp "$URL_BASE/$file"
	if [[ $? -ne 0 ]]; then
		echo "[FATAL] download $file meta-data failed."
		exit 2
	fi
	mv "$TO/api/$file".tmp "$TO/api/$file"
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

# Step 2: Download cask-source
bottles-json --mode list-cask-source > $CASK_SOURCES < "$CASK_JSON"
if [[ $? -ne 0 ]]; then
	echo "[FATAL] cask-source list failed."
	exit 3
fi

# Init common envs for parallel downloading
export enable_urldecode=true
export enable_alternative_path=true
export enable_checksum=true
export by_hash_pattern="./.by-hash/*"

# envs for cask-source
export by_hash=$(realpath $TO/api/cask-source/.by-hash)

export local_dir="$TO/api/cask-source"
parallel --line-buffer -j $HOMEBREW_BOTTLES_JOBS --pipepart -a $CASK_SOURCES download

# cleanup
removal_list=$(mktemp)
cd $local_dir
comm -23 <(find . -type f -not -path "$by_hash_pattern" | sed "s|^./||" | sort) <(awk '{print $3}' $CASK_SOURCES | sort) | tee $removal_list | xargs rm -f
sed 's/^/[INFO] remove /g' $removal_list
clean_hash_file

# chdir back
cd "$TO"

# Step 3: Download bottles (formula only)
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

# Reset BIND_ADDRESS and curl for bottle downloading
BIND_ADDRESS="$BOTTLES_BIND_ADDRESS"
unset CURL_WRAP
curl_init

# parallel downloading
export by_hash=$(realpath $TO/.by-hash)
export local_dir=$TO
export CURL_WRAP="$CURL_WRAP --header @$headers_file"
parallel --line-buffer -j $HOMEBREW_BOTTLES_JOBS --pipepart -a $BOTTLES download

# clean up outdated bottles
removal_list=$(mktemp)
cd $local_dir
comm -23 <(find . -type f -not -path "$by_hash_pattern" -not -path "./api/*" | sed "s|^./||" | sort) <(awk '{print $3}' $BOTTLES | sort) | tee $removal_list | xargs rm -f
sed 's/^/[INFO] remove /g' $removal_list

# clean empty dir. If everything work as expect, this command would do nothing
find . -type d -empty -delete

clean_hash_file

# Step 4: Download bottle manifests (formula only)
# OCI image indexes have no checksum, so download directly (no by-hash).
# Reuses the ghcr CURL_WRAP (Accept + Authorization headers) configured above.

# Create manifests folder here to avoid being cleaned up above.
mkdir -p "$TO/api/manifests"

MANIFESTS=$(mktemp)
bottles-json --mode list-manifests > $MANIFESTS < $FORMULA_JSON
if [[ $? -ne 0 ]]; then
    echo "[FATAL] manifest list failed."
    exit 7
fi

download_manifest() {
	local manifest_dir=${manifest_dir:="$TO/api/manifests"}
	local url filename
	while read url filename; do
		[[ -z "$url" || -z "$filename" ]] && continue
		if $CURL_WRAP -m 600 -sSfRL -o "$manifest_dir/$filename.tmp" "$url"; then
			mv "$manifest_dir/$filename.tmp" "$manifest_dir/$filename"
		else
			echo "[WARN] download manifest failed $url"
			rm -f "$manifest_dir/$filename.tmp"
		fi
	done
}
export -f download_manifest

export manifest_dir="$TO/api/manifests"
parallel --line-buffer -j $HOMEBREW_BOTTLES_JOBS --pipepart -a $MANIFESTS download_manifest

# cleanup outdated manifests
removal_list=$(mktemp)
cd "$manifest_dir"
comm -23 <(find . -type f -name '*.json' | sed "s|^\./||" | sort) <(awk '{print $2}' $MANIFESTS | sort) | tee $removal_list | xargs rm -f
sed 's/^/[INFO] remove /g' $removal_list

cd "$TO"
