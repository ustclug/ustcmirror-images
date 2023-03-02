#!/bin/bash
set -e
apt-get update
apt-get install -y aria2 ca-certificates git wget libghc-bzlib-dev xz-utils musl-dev apt-utils ghc cabal-install haskell-platform libghc-cabal-dev
mkdir /root/.cabal
mv config /root/.cabal/
cabal update
cabal install --lib yaml-0.11.8.0 process containers aeson-2.1.1.0
ghc -O2 stackage.hs -package unordered-containers -package split
rm -rf /root/.cabal && apt-get purge -y --auto-remove libghc-bzlib-dev xz-utils musl-dev apt-utils ghc cabal-install haskell-platform libghc-cabal-dev && rm -rf /var/lib/apt/lists/*
