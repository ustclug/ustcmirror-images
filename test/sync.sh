#!/bin/bash

echo 'Sleep 6s'
sleep 6
echo 'Sleep 5s'
sleep 5
env

if [[ -n $HAS_ERROR ]]; then
    echo Error occurred
    sleep 2
    exit 1
fi

exit 0
