#!/bin/sh
# Julia requires to compile modules in user's home folder.
# But by default, we use 1000:1000 and it has no home folder.
# This script helps create a user with a home folder corresponding to $OWNER.

SYNC_UID=$(echo "$OWNER" | cut -d ':' -f 1)
SYNC_GID=$(echo "$OWNER" | cut -d ':' -f 2)

# Alpine's adduser doesn't support GID parameter,
# and $SYNC_GID would be simply ignored here.
adduser --system --uid "$SYNC_UID" mirror