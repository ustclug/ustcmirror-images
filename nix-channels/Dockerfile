FROM ustcmirror/base:alpine

RUN wget https://nixos.org/releases/nix/nix-2.3.2/nix-2.3.2-x86_64-linux.tar.xz -O /tmp/nix.tar.xz

# Install Nix. To simplify management we only copy binaries and create
# symlinks, and do no further configuration

RUN mkdir /tmp/nix.unpack && \
    tar xpf /tmp/nix.tar.xz -C /tmp/nix.unpack && \
    mkdir /nix && \
    cp -dpr /tmp/nix.unpack/*/store /nix/store && \
    ln -s /nix/store/*-nix-*/bin/* /usr/local/bin && \
    rm -rf /tmp/nix.tar.xz /tmp/nix.unpack

# Required for Nix
RUN apk add ca-certificates

RUN apk add python3 py3-requests py3-pip py3-lxml
RUN pip3 install pyquery

ADD [ "sync.sh", "nix-channels.py", "/" ]
RUN chmod +x /sync.sh
