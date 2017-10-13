FROM ustcmirror/base:debian
MAINTAINER Jiahao Li <gloit042@gmail.com>
ADD ["config", "sync.sh", "build.sh", "stackage.hs", "/"]
RUN bash /build.sh && rm build.sh
