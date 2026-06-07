#!/bin/sh

# Alpine's ssh does not seem to like the idea
# when UID 1000 user is not in /etc/passwd.
# Otherwise, `ssh -V` will not be executed successfully.
SYNC_UID=$(echo "$OWNER" | cut -d ':' -f 1)
adduser --system --uid "$SYNC_UID" mirror
