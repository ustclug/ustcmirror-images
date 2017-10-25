FROM ustcmirror/base:debian
MAINTAINER Jiahao Li <gloit042@gmail.com>
ADD ["config", "sync.sh", "prepare.sh", "stackage.hs", "/"]
RUN bash /prepare.sh && rm prepare.sh
