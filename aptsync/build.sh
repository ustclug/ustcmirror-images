#!/bin/bash

set -e
cd upstream
git apply ../update.patch
cp apt-mirror ..
docker build -t ustcmirror/aptsync ..
