#!/bin/bash

#WINGET_REPO_URL=
#WINGET_REPO_JOBS=

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#DEBUG=

set -e

[[ $DEBUG == true ]] && set -x

exec node /sync-repo.js
