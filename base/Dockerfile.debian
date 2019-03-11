FROM debian:stretch-slim
LABEL maintainer="Jian Zeng <anonymousknight96 AT gmail.com>" \
      org.ustcmirror.images=true
ADD ["entry.sh", "savelog", "/usr/local/bin/"]
VOLUME ["/data", "/log"]
ENTRYPOINT ["entry.sh"]
RUN echo 'Asia/Shanghai' > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata && \
    apt-get update && apt-get install -y wget && \
    wget -O /usr/local/bin/su-exec http://ftp.ustclug.org/misc/su-exec && chmod +x /usr/local/bin/su-exec && \
    apt-get purge -y --auto-remove wget && rm -rf /var/lib/apt/lists/*
