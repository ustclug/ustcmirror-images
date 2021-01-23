FROM ustcmirror/base:alpine-3.11
LABEL maintainer="Yifan Gao <docker@yfgao.com>"
ENV HOMEBREW_BOTTLE_DOMAIN=http://homebrew.bintray.com \
    HOMEBREW_CACHE=/data

RUN apk add --no-cache git curl ncurses ruby ruby-bigdecimal ruby-fiddle ruby-json ruby-etc ruby-irb ruby-json ruby-test-unit && \
    git clone --depth 1 https://github.com/Homebrew/brew.git ~/.linuxbrew && \
    cd ~/.linuxbrew && \
    git clone --depth=1 --branch=master https://github.com/gaoyifan/homebrew-bottle-mirror.git ~/.linuxbrew/Library/Taps/gaoyifan/homebrew-bottle-mirror && \
    mkdir -p ~/.linuxbrew/Library/Taps/homebrew/homebrew-core $HOMEBREW_CACHE
ADD sync.sh pre-sync.sh /
