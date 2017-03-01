#!/bin/bash

export HOME=/root
cat << EOF > /root/.gem/.mirrorrc
---
- from: $UPSTREAM
  to: $TO
  parallelism: 10
  retries: 3
  delete: false
  skiperror: true
EOF
exec gem mirror
