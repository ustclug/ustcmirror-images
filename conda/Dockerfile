FROM ustcmirror/base:alpine
RUN apk add --no-cache python3 && \
    pip3 install conda-mirror
ADD sync.sh /
