#!/bin/bash
set -e
echo "> update package info..."
export HOME=/root
export PATH="$HOME/.linuxbrew/bin:$PATH"
cd ~/.linuxbrew/Library/Taps/homebrew/homebrew-core || exit 1
git init
git remote add origin git://github.com/homebrew/homebrew-core.git
git fetch --depth=1 origin master
git reset --hard origin/master
export HOMEBREW_CACHE=$TO/bottles
mkdir -p "$HOMEBREW_CACHE"
echo "> RUN brew bottle-mirror..."
brew bottle-mirror
for HOMEBREW_TAP in science php dupes nginx apache portable; do
    export HOMEBREW_TAP
    echo "> RUN brew bottle-mirror..."
    git remote set-url origin git://github.com/Homebrew/homebrew-${HOMEBREW_TAP}.git
    git fetch --depth=1 origin master
    git reset --hard origin/master
    export HOMEBREW_CACHE=$TO/bottles-$HOMEBREW_TAP
    mkdir -p "$HOMEBREW_CACHE"
    echo "> RUN brew bottle-mirror $HOMEBREW_TAP ..."
    brew bottle-mirror
done
