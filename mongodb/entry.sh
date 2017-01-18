#!/bin/bash

[[ -n $DEBUG ]] && set -x

MONGO_USER="${MONGO_USER:-mirror}"
MONGO_PASS="${MONGO_PASS:-averylongpass}"
MONGO_DB="${MONGO_DB:-mirror}"

(
    while ! mongo "$MONGO_DB" --eval "db.createUser({ user: '$MONGO_USER', pwd: '$MONGO_PASS', roles: [{ role: 'dbAdmin', db: '$MONGO_DB' }]});"; do
        sleep 2
    done
) 2>/dev/null &

wait

exec mongod --auth
