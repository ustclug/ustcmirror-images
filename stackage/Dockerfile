FROM ustcmirror/base:debian
MAINTAINER Jiahao Li <gloit042@gmail.com>
MAINTAINER Keyu Tao <taoky@ustclug.org>
ADD ["sync.sh", "prepare.sh", "stackage.hs", "/"]
RUN bash /prepare.sh && rm prepare.sh
