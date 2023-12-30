#!/bin/bash
set -e
apt-get update
apt-get install -y aria2 ca-certificates git haskell-stack g++
stack upgrade --binary-only
mkdir /root/.cabal
mv config /root/.cabal/
stack build
cp $(stack path --local-install-root)/bin/stackage /
rm -rf /root/.cabal && apt-get purge -y --auto-remove haskell-stack g++ && rm -rf /var/lib/apt/lists/*
