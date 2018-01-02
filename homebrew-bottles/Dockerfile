FROM ustcmirror/base:alpine
MAINTAINER Yifan Gao <docker@yfgao.com>
ADD *.patch /
ENV HOMEBREW_BOTTLE_DOMAIN=http://homebrew.bintray.com \
    HOMEBREW_CACHE=/data
RUN apk add --no-cache ruby git curl ncurses ruby-json && \
    git clone --depth 1 https://github.com/Linuxbrew/brew.git ~/.linuxbrew && \
    cd ~/.linuxbrew && \
    git apply /linuxbrew-*.patch && \
    git clone --depth=1 --branch=threaded https://github.com/gaoyifan/homebrew-bottle-mirror.git /root/.linuxbrew/Library/Taps/gaoyifan/homebrew-bottle-mirror && \
    mkdir -p ~/.linuxbrew/Library/Taps/homebrew/homebrew-core $HOMEBREW_CACHE
ADD sync.sh pre-sync.sh /
