FROM debian:jessie-slim
MAINTAINER Jian Zeng <anonymousknight96 AT gmail.com>
ADD entry.sh /
RUN echo 'Asia/Shanghai' > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata
