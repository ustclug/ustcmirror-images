#!/bin/bash
set -e

HASKELL_DEPS="ghc libghc-yaml-dev libghc-process-extras-dev \
              libghc-aeson-dev libghc-split-dev"

apt-get update
apt-get install -y aria2 ca-certificates git "$HASKELL_DEPS"
ghc -O2 stackage.hs
apt-get purge --auto-remove -y "$HASKELL_DEPS"
