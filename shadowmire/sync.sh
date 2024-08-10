#!/bin/bash

## EXPORTED IN entry.sh
#TO=

## SET IN ENVIRONMENT VARIABLES
#INDEX_ONLY=
#EXCLUDE=
#UPSTREAM=
#USE_PYPI_INDEX=

set -eu
if [[ $DEBUG = true ]]; then
    set -x
else
    unset DEBUG
fi

INDEX_ONLY=${INDEX_ONLY:-"false"}
USE_PYPI_INDEX=${USE_PYPI_INDEX:-"false"}
UPSTREAM=${UPSTREAM:-"https://pypi.org"}
EXCLUDE=${EXCLUDE:-""}

ARG=""

if [[ $INDEX_ONLY = false ]]; then
    ARG="$ARG --sync-packages"
else
    ARG="$ARG --no-sync-packages"
fi

if [[ $UPSTREAM != "https://pypi.org" ]]; then
    ARG="$ARG --shadowmire-upstream $UPSTREAM"
fi

if [[ $USE_PYPI_INDEX = true ]]; then
    ARG="$ARG --use-pypi-index"
fi

exec shadowmire --repo "$TO" sync $ARG $EXCLUDE
