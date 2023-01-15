#!/bin/bash
set -e
set -o pipefail
[[ $DEBUG = true ]] && set -x

/ghcupsync

mkdir -p "$TO/sh"
pushd "$TO/sh"
curl https://raw.githubusercontent.com/haskell/ghcup-hs/master/scripts/bootstrap/bootstrap-haskell -o bootstrap-haskell
sed -i 's|https://downloads.haskell.org/~ghcup|https://mirrors.ustc.edu.cn/ghcup/downloads.haskell.org/~ghcup|' bootstrap-haskell
curl https://raw.githubusercontent.com/haskell/ghcup-hs/master/scripts/bootstrap/bootstrap-haskell.ps1 -o bootstrap-haskell.ps1
sed -i 's|https://www.haskell.org/ghcup/sh/bootstrap-haskell|https://mirrors.ustc.edu.cn/ghcup/sh/bootstrap-haskell|' bootstrap-haskell.ps1
sed -i 's|https://repo.msys2.org/distrib/|https://mirrors.ustc.edu.cn/msys2/distrib/|' bootstrap-haskell.ps1
popd
