#!/usr/bin/env bash

VERIFY_TLS=${VERIFY_TLS:-"false"}

if [ -n "$NEEDS_LOGIN" ]; then
  skopeo login --tls-verify="$VERIFY_TLS" "$REGISTRY_HOST" -u "$REGISTRY_USERNAME" -p "$REGISTRY_PASSWORD"
  if [ $? -ne 0 ]; then
    echo "Registry login failed"
    exit 255
  fi
fi

exec skopeo --insecure-policy sync --dest-tls-verify="$VERIFY_TLS" --src yaml --dest docker /etc/skopeo-images.yaml "$REGISTRY_HOST"
