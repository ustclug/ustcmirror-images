#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#REPO=

## SET IN ENVIRONMENT VARIABLES
#BIND_ADDRESS=
#UPSTREAM=
#YUKINA_SIZE_LIMIT=
#YUKINA_FILTER=
#YUKINA_EXTRA=

set -eu
[[ $DEBUG = true ]] && set -x

BIND_ADDRESS=${BIND_ADDRESS:-}
YUKINA_SIZE_LIMIT=${YUKINA_SIZE_LIMIT:-"512g"}
YUKINA_FILTER=${YUKINA_FILTER:-}
YUKINA_EXTRA=${YUKINA_EXTRA:-}
YUKINA_REPO=${YUKINA_REPO:-$REPO}

if [[ $DEBUG = true ]]; then
    export RUST_LOG="yukina=debug"
fi

export NO_COLOR=1

# handling with xargs trick
# https://github.com/ustclug/ustcmirror-images/issues/111

filter_array=()
while IFS= read -r -d '' arg; do
    filter_array+=("$arg")
done < <(echo "$YUKINA_FILTER" | xargs printf "%s\0")
extra_array=()
while IFS= read -r -d '' arg; do
    extra_array+=("$arg")
done < <(echo "$YUKINA_EXTRA" | xargs printf "%s\0")

json_log_args=()
if compgen -G "/nginx-log/${YUKINA_REPO}_json.log*" > /dev/null; then
    json_log_args=(--log-format mirror-json --log-suffix _json)
fi

exec yukina --name "$YUKINA_REPO" \
    --log-path "/nginx-log" \
    "${json_log_args[@]}" \
    --repo-path "$TO" \
    --size-limit "$YUKINA_SIZE_LIMIT" \
    --url "$UPSTREAM" \
    --remote-sizedb "$TO/.yukina-remote.db" \
    --local-sizedb "$TO/.yukina-local.db" \
    --output-stats \
    "${filter_array[@]}" "${extra_array[@]}"
