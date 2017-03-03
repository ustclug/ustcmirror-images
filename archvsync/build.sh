#!/bin/bash

cd upstream || exit 1
git apply ../update.patch
cp bin/{common,ftpsync} ..
docker build -t ustcmirror/archvsync ..
