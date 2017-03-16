#!/bin/bash

if [[ -z $APTSYNC_BASEURL || -z $APTSYNC_DISTS ]]; then
    echo >&2 'Invalid args'
    exit 1
fi

LIST='/etc/apt/mirror.list'

cat > "$LIST" << EOF
set base_path         /var/spool/apt-mirror
set mirror_path       $TO
set skel_path         $TO
set var_path          $LOGDIR
set run_postmirror    0
set nthreads          $APTSYNC_NTHREADS
set unlink            $APTSYNC_UNLINK
EOF

chown -R "$OWNER" /var/spool/apt-mirror/

IFS=':' read -ra dists <<< "$APTSYNC_DISTS"
for dist in "${dists[@]}"; do
    IFS='|' read -ra data <<< "$dist"
    # 0: releases
    # 1: componenets
    # 2: architectures
    IFS=' ' read -ra releases <<< "${data[0]}"
    for release in "${releases[@]}"; do
        for arch in ${data[2]}; do
            echo "deb-$arch" "$APTSYNC_BASEURL" "$release" "${data[1]}"
        done
    done
done | tee -a "$LIST"
