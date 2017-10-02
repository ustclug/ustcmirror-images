FROM ustcmirror/base:alpine
MAINTAINER Jiahao Li <gloit042@gmail.com>
ENV HACKAGE_BASE_URL=https://hackage.haskell.org
RUN apk add --no-cache wget ca-certificates
ADD ["sync.sh", "/"]
