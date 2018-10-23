FROM ustcmirror/base:alpine
MAINTAINER Elliot Saba <staticfloat@gmail.com>
RUN apk add --no-cache python3 git && \
    git clone https://github.com/sunoru/julia-mirror /julia-mirror
RUN pip3 install gitpython toml
ADD sync.sh /
