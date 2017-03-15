#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#APTSYNC_BASEURL=
#APTSYNC_DIST_*=

set -e
[[ $DEBUG = true ]] && set -x

exec apt-mirror
