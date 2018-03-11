FROM alpine:3.7
LABEL maintainer="Jian Zeng <anonymousknight96 AT gmail.com>" \
      org.ustcmirror.images=true
ADD ["entry.sh", "savelog", "/usr/local/bin/"]
VOLUME ["/data", "/log"]
ENTRYPOINT ["entry.sh"]
RUN apk add --no-cache bash tzdata su-exec && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
