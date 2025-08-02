FROM rust:latest AS builder

WORKDIR /app
ADD ./upstream /app/

ARG CARGO_BUILD_EXTRA=" "
RUN cargo build --release ${CARGO_BUILD_EXTRA}

FROM ustcmirror/base:debian

COPY --from=builder /app/target/release/rustup-mirror /usr/local/bin

RUN apt update \
  && apt install -y \
    ca-certificates \
    git \
    libssl3

ADD sync.sh /
