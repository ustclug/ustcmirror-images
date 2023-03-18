FROM ghcr.io/ustcmirror/base:debian
MAINTAINER Kai Ma <ksqsf@mail.ustc.edu.cn>
ADD ["config", "sync.sh", "prepare.sh", "ghcupsync.hs", "ghcupsync.cabal", "/"]
RUN bash /prepare.sh && rm prepare.sh
