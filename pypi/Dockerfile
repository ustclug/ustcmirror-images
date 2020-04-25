FROM ustcmirror/base:alpine
MAINTAINER Yifan Gao <docker@yfgao.com>
ENV PYPI_MASTER=https://pypi.python.org \
    BANDERSNATCH_WORKERS=3 \
    BANDERSNATCH_STOP_ON_ERROR=true \
    BANDERSNATCH_TIMEOUT=20
RUN apk add --no-cache python3 python3-dev musl-dev gcc libxml2 libxslt libxml2-dev libxslt-dev && \
    python3 -m ensurepip -U && \
    pip3 install bandersnatch && \
    apk del --purge python3-dev musl-dev gcc libxml2-dev libxslt-dev && \
    rm -rf /usr/lib/python*/ensurepip /root/.cache/
ADD sync.sh pre-sync.sh /
