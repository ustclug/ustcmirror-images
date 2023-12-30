#!/bin/bash
set -e

HASKELL_DEPS="ghc libghc-aeson-dev libghc-lens-dev libghc-lens-aeson-dev \
              libghc-network-uri-dev libghc-split-dev libghc-typed-process-dev \
              libghc-yaml-dev"
# Please use ldd to check the dependencies of compiled binary
HASKELL_KEEP="libyaml-0-2"

apt-get update
apt-get install -y aria2 ca-certificates git $HASKELL_DEPS $HASKELL_KEEP

# compile with Haskell language extensions
ghc -O2 -XScopedTypeVariables -XOverloadedStrings ghcupsync.hs

rm -rf /ghcupsync.* && apt-get purge -y --auto-remove $HASKELL_DEPS && rm -rf /var/lib/apt/lists/*
