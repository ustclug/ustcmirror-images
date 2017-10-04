#!/bin/bash
set -e
set -o pipefail

jobs_max=5

function pull_hackage () {
    local_pkgs=`mktemp -t local_pkgs.XXXX`
    remote_pkgs=`mktemp -t remote_pkgs.XXXX`

    echo "Sync start"
    cd $TO

    rm index.tar.gz || true &> /dev/null

    echo "Download latest index ..."
    wget "$HACKAGE_BASE_URL/packages/index.tar.gz" -O index.tar.gz &> /dev/null


    mkdir -p package

    # save remote package index to temporary file
    echo "Build remote package list ..."
    tar -ztf index.tar.gz | awk 'BEGIN{FS="/"}{print($1"-"$2)}' | sort > $remote_pkgs || true
    echo "Remote package list built"
    
    # save local package index to temporary file
    echo "Building local package list ..."

    # check if package/ is empty
    local_archives=$(shopt -s nullglob dotglob; echo package/*)
    if [[ ${#local_archives[@]} -gt 0 ]]; then
        local_archives=(package/*)
        local_archives=(${local_archives[@]#package/})
        printf "%s\n" ${local_archives[@]%.tar.gz} | sort > $local_pkgs
    else
        touch $local_pkgs
    fi
    
    # Files that are unique to remote_pkgs are newer
    # download them into local
    for pkg in $(comm $remote_pkgs $local_pkgs -23); do
        if [[ $pkg = *-preffered-versions ]]; then
            continue
        fi

        while [[ $(jobs | wc -l) -ge $jobs_max ]]; do
            sleep 0.5
        done

        download_pkg $pkg &
    done

    # wait downloading jobs
    wait

    # Files that are unique to local packages are deprecated
    # remove them from local
    for pkg in $(comm $remote_pkgs $local_pkgs -13); do
        if [[ $pkg == "preferred-versions" ]]; then
            continue
        fi
        echo "Removing $pkg.tar.gz ..."
        rm "package/$pkg.tar.gz" || true &> /dev/null
    done

    cp index.tar.gz 00-index.tar.gz
}

function download_pkg () {
    pkg=$1
    name="$pkg.tar.gz"
    echo "Download $pkg.tar.gz ..."
    wget "$HACKAGE_BASE_URL/package/$pkg/$name" -O "package/$name" &> /dev/null
}


function rmtemp () {
    echo "Remove temporary files"
    [[ ! -z $local_pkgs ]] && (rm $local_pkgs $remote_pkgs; true)
}

trap rmtemp EXIT
pull_hackage
