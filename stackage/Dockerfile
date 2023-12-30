FROM ustcmirror/base:debian
MAINTAINER Jiahao Li <gloit042@gmail.com>
MAINTAINER Keyu Tao <taoky@ustclug.org>
ADD ["config", "sync.sh", "prepare.sh", "stackage.hs", \
     "package.yaml", "stack.yaml", "stackage.cabal", \
     "/tmp"]
WORKDIR /tmp
RUN bash ./prepare.sh && rm prepare.sh
