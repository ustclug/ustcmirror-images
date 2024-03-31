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

if [[ $DEBUG = true ]]; then
    export RUST_LOG="yukina=debug"
fi

export NO_COLOR=1

exec yukina --name "$REPO" \
    --log-path "/nginx-log" \
    --repo-path "$TO" \
    --size-limit "$YUKINA_SIZE_LIMIT" \
    --url "$UPSTREAM" \
    --remote-sizedb "$TO/.yukina-remote.db" \
    --local-sizedb "$TO/.yukina-local.db" \
    $YUKINA_FILTER $YUKINA_EXTRA
