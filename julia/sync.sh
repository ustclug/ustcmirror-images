#!/bin/bash

mkdir -p /data/tmp
python3 /julia-mirror/scripts/mirror_julia.py /data --logging-file /logs/mirror_julia.log --temp-dir=/data/tmp
rm -rf /data/tmp
