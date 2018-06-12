#!/bin/bash

get_hostname() {
    sed -re 's|[^/]*//([^@]*@)?([^:/]*).*|\2|' <<< "$1"
}
get_hostname_and_path() {
    sed -re 's|[^/]*//([^@]*@)?([^:/]*)(:[0-9]+)?(/.*[^/])+/?$|\2\4|' <<< "$1"
}

_LIST='/etc/apt/mirror.list'
_BASE='/var/spool/apt-mirror'

cat > "$_LIST" << EOF
set base_path         $_BASE
set mirror_path       \$base_path/mirror
set skel_path         \$base_path/skel
set var_path          $LOGDIR
set run_postmirror    0
set nthreads          $APTSYNC_NTHREADS
set unlink            $APTSYNC_UNLINK
EOF

chown -R "$OWNER" "$_BASE"
if [[ $APTSYNC_CREATE_DIR == true ]]; then
	ln -s "$TO" "$_BASE/mirror/$(get_hostname "$APTSYNC_URL")"
else
	_LINK_TARGET="$_BASE/mirror/$(get_hostname_and_path "$APTSYNC_URL")"
	mkdir -p $_LINK_TARGET
	rmdir $_LINK_TARGET
	ln -Ts "$TO" "$_LINK_TARGET"
fi

IFS=':' read -ra dists <<< "$APTSYNC_DISTS"
for dist in "${dists[@]}"; do
    IFS='|' read -ra data <<< "$dist"
    # 0: releases
    # 1: componenets
    # 2: architectures
    IFS=' ' read -ra releases <<< "${data[0]}"
    for release in "${releases[@]}"; do
        for arch in ${data[2]}; do
            echo "deb-$arch" "$APTSYNC_URL" "$release" "${data[1]}"
        done
    done
done | tee -a "$_LIST"
