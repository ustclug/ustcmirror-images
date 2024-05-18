#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#APTSYNC_URL=
#APTSYNC_DISTS=
#BIND_ADDRESS=

set -e
[[ $DEBUG = true ]] && set -x

exec apt-mirror
