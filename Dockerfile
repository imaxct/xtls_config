FROM alpine:latest
WORKDIR /root
COPY install.sh /root/install.sh
COPY config_xtls.sh /root/config_xtls.sh

RUN set -ex \
  && apk add --no-cache curl unzip openssl tzdata ca-certificates \
  && mkdir -p /var/log/xray /usr/share/xray \
  && chmod +x /root/install.sh \
  && chmod +x /root/config_xtls.sh \
  && /root/install.sh \
  && /root/config_xtls.sh

ENV TZ=Asia/Shanghai
CMD [ "/root/xray", "-config", "/root/config.json" ]