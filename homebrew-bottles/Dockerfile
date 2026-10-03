FROM rust:alpine AS builder
WORKDIR /usr/src/homebrew-sync/
COPY homebrew-sync .
RUN apk add --no-cache musl-dev cmake make perl
RUN cargo build --release --locked

FROM ustcmirror/base:alpine
LABEL bind_support=true
RUN apk add --no-cache ca-certificates
ADD sync.sh upstream.sh /
COPY --from=builder /usr/src/homebrew-sync/target/release/homebrew-sync /usr/local/bin/
