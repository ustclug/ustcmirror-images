FROM rust:1-trixie AS builder

RUN apt update \
  && apt install -y --no-install-recommends git

# Use fork version for now
RUN git clone https://github.com/taoky/rustup-mirror app && \
  cd app && \
  git checkout d1ecb66b11e6d9d50d1079137189928dc16612af

WORKDIR /app

ARG CARGO_BUILD_EXTRA=" "
RUN cargo build --release ${CARGO_BUILD_EXTRA}

FROM ustcmirror/base:debian
LABEL maintainer="Erina Init <erina@mail.ustc.edu.cn>"

COPY --from=builder /app/target/release/rustup-mirror /usr/local/bin

RUN apt update \
  && apt install -y \
    ca-certificates \
    libssl3

ADD sync.sh upstream.sh /
