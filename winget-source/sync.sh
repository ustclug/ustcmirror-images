#!/bin/bash

#WINGET_REPO_URL=
#WINGET_REPO_JOBS=

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#DEBUG=

export NODE_ENV=production

set -e

exec node /sync-repo.js
