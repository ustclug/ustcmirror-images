FROM ustcmirror/base:debian
LABEL maintainer="Jiahao Li <gloit042@gmail.com>"
LABEL maintainer="Keyu Tao <taoky@ustclug.org>"
ADD ["sync.sh", "stackage.hs", "/"]
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt <<EOF
#!/bin/bash

HASKELL_DEPS="ghc libghc-yaml-dev libghc-process-extras-dev \
              libghc-aeson-dev libghc-split-dev"
# Please use ldd to check the dependencies of compiled binary
HASKELL_KEEP="libyaml-0-2"

apt-get update
apt-get install -y aria2 ca-certificates git $HASKELL_DEPS $HASKELL_KEEP
ghc -O2 stackage.hs

rm -rf stackage.* && apt-get purge --auto-remove -y $HASKELL_DEPS

EOF
