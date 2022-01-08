#!/bin/bash
# set -e

mkdir /root/.cabal
mv config /root/.cabal/

apt-get update
apt-get install -y aria2 ca-certificates git wget xz-utils apt-utils build-essential curl libffi-dev libgmp-dev libgmp10 libncurses-dev libncurses5 libtinfo5 libnuma-dev

curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_MINIMAL=1 sh
source /root/.ghcup/env
ghcup install ghc 9.0.2
cat /root/.ghcup/logs/*
ghcup install cabal 3.6.2.0
ghcup set ghc 9.0.2
cabal update
cabal build -O2
cp $(cabal list-bin ghcupsync) /

rm -rf /dist* /root/.cabal /root/.ghcup /root/.ghc && apt-get purge -y --auto-remove build-essential curl libffi-dev libgmp-dev libncurses-dev libnuma-dev && rm -rf /var/lib/apt/lists/*
