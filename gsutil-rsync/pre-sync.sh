#!/bin/bash

set_upstream "$GS_URL"

mkdir -p /.gsutil
chown -R "$OWNER" /.gsutil
