#!/bin/bash

SYNC_EXTRA=${SYNC_EXTRA:-}
exec python3 /usr/local/lib/tunasync/sync.py $SYNC_EXTRA
