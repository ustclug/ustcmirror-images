FROM rust:latest AS builder

RUN apt update \
  && apt install -y --no-install-recommends git

RUN git clone https://github.com/jiegec/rustup-mirror app && \
  cd app && \
  git checkout v0.9.0

WORKDIR /app

ARG CARGO_BUILD_EXTRA=" "
RUN cargo build --release ${CARGO_BUILD_EXTRA}

FROM ustcmirror/base:debian

COPY --from=builder /app/target/release/rustup-mirror /usr/local/bin

RUN apt update \
  && apt install -y \
    ca-certificates \
    libssl3

ADD sync.sh /
