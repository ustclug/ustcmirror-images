#!/bin/bash

CONDA_UPSTREAM_CHANNEL=${CONDA_UPSTREAM_CHANNEL:-"conda-forge"}
CONDA_PLATFORM=${CONDA_PLATFORM:-"noarch linux-{64,32,armv6l,armv7l,ppc64le} {osx,win}-{64,32}"}
CONDA_TEMP_DIRECTORY=${CONDA_TEMP_DIRECTORY:-"$TO/.conda-temp"}
CONDA_NUM_THREADS=${CONDA_NUM_THREADS:-0}

mkdir -p $CONDA_TEMP_DIRECTORY

for channel in $(eval echo $CONDA_UPSTREAM_CHANNEL); do
    mkdir -p $TO/$channel
    for platform in $(eval echo $CONDA_PLATFORM); do
        echo "> channel:$channel platform:$platform"
        conda-mirror -vv --upstream-channel $channel --target-directory $TO/$channel --platform $platform --temp-directory $CONDA_TEMP_DIRECTORY --num-threads $CONDA_NUM_THREADS
    done
done

rm -r $CONDA_TEMP_DIRECTORY
