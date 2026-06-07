#!/bin/sh

if [ -z "$REMOTE" ]; then
    echo "rsync://dl.fedoraproject.org"
else
    echo "$REMOTE/$MODULE"
fi
