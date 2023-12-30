FROM ustcmirror/base:debian
LABEL maintainer="Keyu Tao <taoky@ustclug.org>"
RUN apt update && apt install -y dnf createrepo-c dnf-plugins-core python3 python3-requests && \
    sed 's/enabled = true/enabled = false/' -i /etc/dnf/plugins/local.conf
ADD tunasync /usr/local/lib/tunasync
ADD sync.sh /
