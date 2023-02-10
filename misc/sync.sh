#!/bin/bash

#DOWNLOAD_LINKS=

set -u

[[ $DEBUG = true ]] && set -x

return_code=0

IFS=$'\n'
for line in $DOWNLOAD_LINKS; do
    unset IFS
    set -- $line
    filename=$1
    link=$2
    echo "[INFO] Downloading $link to $TO/$filename.tmp"
    if ! wget "$link" -O "$TO"/"$filename".tmp; 
    then
        echo "[ERROR] Downloading $link failed"
        rm -f "$TO"/"$filename".tmp
        return_code=1
    else
        mv "$TO"/"$filename.tmp" "$TO"/"$filename"
    fi
done

exit $return_code
