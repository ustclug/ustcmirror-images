#!/bin/bash

set_upstream "http://rubygems.org/"

mkdir -p "$HOME/.gem"
chown -R "$OWNER" "$HOME"
