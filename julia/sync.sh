#!/bin/sh

mkdir -p $TO/tmp
python3 /julia-mirror/scripts/mirror_julia.py /data --logging-file /logs/mirror_julia.log --temp-dir=/data/tmp
rm -rf /data/tmp
