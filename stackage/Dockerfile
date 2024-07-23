FROM ustcmirror/base:debian
LABEL maintainer="Jiahao Li <gloit042@gmail.com>"
LABEL maintainer="Keyu Tao <taoky@ustclug.org>"
ADD ["sync.sh", "prepare.sh", "stackage.hs", "/"]
RUN bash /prepare.sh && rm prepare.sh
