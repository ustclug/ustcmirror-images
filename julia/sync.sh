#!/bin/sh

mkdir -p ${TO}/tmp
python3 /julia-mirror/scripts/mirror_julia.py ${TO} --temp-dir=${TO}/tmp
rm -rf ${TO}/tmp
