#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#DEBUG=
#WINGET_REPO_URL=
#WINGET_REPO_JOBS=

set -e

if [[ $DEBUG = true ]]; then
    set -x
else
    export NODE_ENV=production
fi

exec node /sync-repo.js
