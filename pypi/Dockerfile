FROM ustcmirror/base:alpine
MAINTAINER Yifan Gao <docker@yfgao.com>
ENV PYPI_MASTER=https://pypi.python.org \
    BANDERSNATCH_WORKERS=3 \
    BANDERSNATCH_STOP_ON_ERROR=true \
    BANDERSNATCH_TIMEOUT=20
RUN apk add --no-cache py-pip && \
    pip install bandersnatch
ADD sync.sh pre-sync.sh /
