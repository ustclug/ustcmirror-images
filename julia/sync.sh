#!/bin/sh

mkdir -p $tmpdir
python3 /julia-mirror/scripts/mirror_julia.py $TO --temp-dir=$tmpdir
