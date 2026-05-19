#!/usr/bin/env bash

VERIFY_TLS=${VERIFY_TLS:-"false"}

if [ ! -f /etc/skopeo-images.yaml ]; then
  echo "Please bind mount skopeo config file to /etc/skopeo-images.yaml"
  exit 255
fi

if [ -n "$NEEDS_LOGIN" ]; then
  skopeo login --tls-verify="$VERIFY_TLS" "$REGISTRY_HOST" -u "$REGISTRY_USERNAME" -p "$REGISTRY_PASSWORD"
  if [ $? -ne 0 ]; then
    echo "Registry login failed"
    exit 255
  fi
fi

exec skopeo --insecure-policy sync --dest-tls-verify="$VERIFY_TLS" --scoped --src yaml --dest docker /etc/skopeo-images.yaml "$REGISTRY_HOST"
