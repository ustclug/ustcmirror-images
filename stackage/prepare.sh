#!/bin/bash
set -e
apt-get update
apt-get install -y aria2 ca-certificates git wget libghc-bzlib-dev xz-utils musl-dev apt-utils ghc cabal-install haskell-platform libghc-cabal-dev
mkdir /root/.cabal
mv config /root/.cabal/
cabal update
cabal install yaml process containers aeson --force-reinstalls
ghc -O2 -optl-static stackage.hs
rm -rf /root/.cabal && apt-get purge -y --auto-remove libghc-bzlib-dev xz-utils musl-dev apt-utils ghc cabal-install haskell-platform libghc-cabal-dev && rm -rf /var/lib/apt/lists/*
