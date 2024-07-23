FROM ustcmirror/base:debian
LABEL maintainer="Kai Ma <ksqsf@mail.ustc.edu.cn>"
ADD ["sync.sh", "prepare.sh", "ghcupsync.hs", "/"]
RUN bash /prepare.sh && rm prepare.sh
