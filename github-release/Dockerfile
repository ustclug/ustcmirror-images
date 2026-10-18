FROM ustcmirror/base:alpine
LABEL maintainer="Yulong Ming <myl.ustc@gmail.com>"
LABEL bind_support=true
RUN apk add --no-cache python3 py3-requests py3-yaml py3-pydantic py3-pydantic-core
ADD tunasync /usr/local/lib/tunasync
ADD sync.sh upstream.sh /
