#!/bin/bash
set -e
echo "> update package info..."
export HOMEBREW_REPO=${HOMEBREW_REPO:-"git://github.com/homebrew/homebrew-core.git"}
export TARGET_OS=${TARGET_OS:-"mac"}
export HOME=/root
export PATH="$HOME/.linuxbrew/bin:$PATH"
cd ~/.linuxbrew/Library/Taps/homebrew/homebrew-core || exit 1
git init
git remote add origin "$HOMEBREW_REPO"
git fetch --depth=1 origin master
git reset --hard origin/master
export HOMEBREW_CACHE=$TO/bottles
mkdir -p "$HOMEBREW_CACHE"
echo "> RUN brew bottle-mirror..."
brew bottle-mirror "$TARGET_OS"
