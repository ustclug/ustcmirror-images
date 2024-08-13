FROM ustcmirror/base:alpine
LABEL maintainer="Jian Zeng <anonymousknight96 AT gmail.com>"
LABEL bind_support=true
VOLUME ["/debian"]
ADD ["sync.sh", "pre-sync.sh", "/"]
ADD ["jigdo-mirror", "cd-mirror", "/usr/local/bin/"]
ADD jigdo-mirror.conf.in /etc/jigdo/
RUN <<EOF
set -euo pipefail
apk add --no-cache wget ca-certificates rsync
mkdir -p /etc/jigdo
wget 'https://ftp.lug.ustc.edu.cn/misc/jigdo-bin-0.7.3.tar.bz2'
echo "58b8a6885822e55f365c99131c906f16ceaaf657c566e10f410d026704cad157  jigdo-bin-0.7.3.tar.bz2" | sha256sum -c -
tar xf jigdo-bin-0.7.3.tar.bz2 jigdo-bin-0.7.3/jigdo-file
mv jigdo-bin-0.7.3/jigdo-file /usr/local/bin/
rm -rf jigdo-bin-*
EOF
