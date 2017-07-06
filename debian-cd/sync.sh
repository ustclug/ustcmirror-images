#!/bin/bash

#REPO=

## EXPORTED IN entry.sh
#TO=
#LOGDIR=
#LOGFILE=

## SET IN ENVIRONMENT VARIABLES
#DEBUG=

set -eu
[[ $DEBUG = true ]] && set -x

exec cd-mirror
