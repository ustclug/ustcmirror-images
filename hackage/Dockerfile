FROM ustcmirror/curl-helper
LABEL maintainer="Jiahao Li <gloit042@gmail.com>"
ENV HACKAGE_BASE_URL=https://hackage.haskell.org
RUN apk add --no-cache wget ca-certificates coreutils
ADD ["sync.sh", "/"]
