FROM alpine:latest
WORKDIR /root
COPY install.sh /root/install.sh
COPY run.sh /root/run.sh

RUN set -ex \
  && apk add --no-cache curl unzip openssl tzdata ca-certificates \
  && mkdir -p /var/log/xray /usr/share/xray \
  && chmod +x /root/install.sh \
  && chmod +x /root/run.sh \
  && /root/install.sh

ENV TZ=Asia/Shanghai
CMD [ "/root/run.sh" ]