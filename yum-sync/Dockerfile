FROM ghcr.io/ustcmirror/base:debian AS builder
COPY binder.c /tmp/binder.c
RUN apt update && apt install -y build-essential && \
    gcc -Wall -fPIC -shared -o /tmp/binder.so /tmp/binder.c

FROM ghcr.io/ustcmirror/base:debian
LABEL maintainer="Keyu Tao <taoky@ustclug.org>"
RUN echo 'deb http://deb.debian.org/debian bullseye-backports main' > /etc/apt/sources.list.d/backports.list && \
    apt update && apt install -y dnf createrepo-c dnf-plugins-core python3 python3-requests && \
    sed 's/enabled = true/enabled = false/' -i /etc/dnf/plugins/local.conf
ADD tunasync /usr/local/lib/tunasync
ADD sync.sh /
COPY --from=builder /tmp/binder.so /usr/local/lib/binder.so
ENV LD_PRELOAD=/usr/local/lib/binder.so
