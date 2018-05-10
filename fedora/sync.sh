#!/bin/bash

set -e
[[ $DEBUG = true ]] && set -x

exec quick-fedora-mirror
