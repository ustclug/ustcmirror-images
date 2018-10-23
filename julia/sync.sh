#!/bin/sh

mkdir -p ${TO}/tmp
python3 /julia-mirror/scripts/mirror_julia.py ${TO} --logging-file ${LOGDIR}/mirror_julia.log --temp-dir=${TO}/tmp
rm -rf ${TO}/tmp
