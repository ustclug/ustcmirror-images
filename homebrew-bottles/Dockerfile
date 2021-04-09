FROM rust:1-alpine as builder
WORKDIR /usr/src/bottles-json/
COPY bottles-json .
RUN apk add --no-cache musl-dev
RUN cargo build --release

FROM ustcmirror/curl-helper
LABEL maintainer="Yifan Gao docker@yfgao.com"
RUN apk add --no-cache jq parallel bash sed gawk
ADD sync.sh /
COPY --from=builder /usr/src/bottles-json/target/release/bottles-json /usr/local/bin/
