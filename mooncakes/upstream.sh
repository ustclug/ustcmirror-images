#!/bin/sh

MOONCAKES_INDEX_URL="${MOONCAKES_INDEX_URL:-https://mooncakes.io/git/index}"
MOONCAKES_BUCKET="${MOONCAKES_BUCKET:-moonbitlang-mooncakes}"

echo "$MOONCAKES_INDEX_URL"
echo "s3://$MOONCAKES_BUCKET"
