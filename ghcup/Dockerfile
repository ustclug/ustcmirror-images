FROM ustcmirror/base:debian
LABEL maintainer="Kai Ma <ksqsf@mail.ustc.edu.cn>"
ADD ["sync.sh", "ghcupsync.hs", "/"]
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt <<EOF
#!/bin/bash

HASKELL_DEPS="ghc libghc-aeson-dev libghc-lens-dev libghc-lens-aeson-dev \
              libghc-network-uri-dev libghc-split-dev libghc-typed-process-dev \
              libghc-yaml-dev"
# Please use ldd to check the dependencies of compiled binary
HASKELL_KEEP="libyaml-0-2"

apt-get update
apt-get install -y aria2 ca-certificates git curl $HASKELL_DEPS $HASKELL_KEEP

# compile with Haskell language extensions
ghc -O2 -XScopedTypeVariables -XOverloadedStrings ghcupsync.hs

rm -rf /ghcupsync.* && apt-get purge -y --auto-remove $HASKELL_DEPS

EOF
