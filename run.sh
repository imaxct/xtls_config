#!/bin/sh

[ -z "$AZ_DOMAIN" ] && echo "Azure dns record name not set, exit" && exit 1
[ -z "$AZ_REGION" ] && echo "Azure region name not set, exit" && exit 1

$DOMAIN_NAME="$AZ_DOMAIN.$AZ_REGION.azurecontainer.io"

mkdir -p /etc/xray/

curl https://get.acme.sh | sh
acme.sh --upgrade --auto-upgrade
acme.sh --issue  -d $DOMAIN_NAME --standalone --ecc --force
acme.sh --installcert -d $DOMAIN_NAME --cert-file /etc/xray/cert.cer --key-file /etc/xray/cert.key --ecc --force
chmod 644 /etc/xray/cert.cer
chmod 644 /etc/xray/cert.key

# set client password via environment variable or generate one.
DEFAULT_PASSWORD=$(cat /proc/sys/kernel/random/uuid | base64)
CLIENT_PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}

cat >/root/config.json <<EOF
{
  "log": {
    "access": "",
    "error": "",
    "loglevel": "debug",
    "dnsLog": false
  },
  "dns": {
    "hosts": {},
    "servers": [
      {
        "address": "https+local://1.1.1.1/dns-query",
        "domains": [],
        "expectIPs": [],
        "skipFallback": false
      },
      {
        "address": "https+local://dns.google/dns-query",
        "domains": [],
        "expectIPs": [],
        "skipFallback": false
      }
    ],
    "queryStrategy": "UseIP",
    "disableCache": false,
    "disableFallback": false,
    "disableFallbackIfMatch": false,
    "tag": "dns"
  },
  "routing": {
    "domainStrategy": "AsIs",
    "domainMatcher": "hybrid",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "ip": [
          "geoip:cn"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "domain": [
          "geosite:category-ads-all"
        ],
        "outboundTag": "block"
      }
    ],
    "balancers": []
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "%%password%%",
            "flow": "xtls-rprx-direct"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "alpn": [
            "http/1.1",
            "h2"
          ],
          "certificates": [
            {
              "certificateFile": "/etc/xray/cert.cer",
              "keyFile": "/etc/xray/cert.key",
              "ocspStapling": 3600
            }
          ],
          "minVersion": "1.2"
        }
      },
      "tag": "trojan_inbound"
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole",
      "settings": {
        "response": {
          "type": "none"
        }
      }
    }
  ]
}
EOF

sed -i "s/%%password%%/$CLIENT_PASSWORD/g" /root/config.json

echo "Client password is: $CLIENT_PASSWORD, please keep it."

cd /root
/root/xray -config /root/config.json