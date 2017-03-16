#!/bin/bash

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#APTSYNC_BASEURL=
#APTSYNC_DISTS=

set -e
[[ $DEBUG = true ]] && set -x

exec apt-mirror
