#!/usr/bin/env bash

skopeo login -u mirror -p "$REGISTRY_PASSWD" "$REGISTRY_HOST"
exec skopeo --insecure-policy sync --scoped --src yaml --dest docker /etc/skopeo-images.yaml "$REGISTRY_HOST"
