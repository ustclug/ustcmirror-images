#!/bin/bash
set -e
apk add --no-cache wget ca-certificates rsync
mkdir -p /etc/jigdo
wget 'https://ftp.lug.ustc.edu.cn/misc/jigdo-bin-0.7.3.tar.bz2'
tar xf jigdo-bin-0.7.3.tar.bz2 jigdo-bin-0.7.3/jigdo-file
mv jigdo-bin-0.7.3/jigdo-file /usr/local/bin/
rm -rf jigdo-bin-*
