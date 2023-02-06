#!/bin/sh
domain_name=$1
su root
apt update && apt upgrade

# install curl
if ! command -v curl &> /dev/null
then
    apt install curl
fi

#configure cert
curl https://get.acme.sh | sh
mkdir -p /etc/xray
acme.sh --issue  -d $domain_name --standalone --ecc --force
acme.sh --installcert -d $domain_name --cert-file /etc/xray/cert.cer --key-file /etc/xray/cert.key --ecc --force
chmod 644 /etc/xray/cert.cer
chmod 644 /etc/xray/cert.key

#install xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
password=$(echo $(xray uuid) | base64)
cat >/usr/local/etc/xray/config.json <<EOL
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
EOL

sed -i "s/%%password%%/$password/g" /usr/local/etc/xray/config.json
systemctl enable xray.service
systemctl restart xray.service
echo "Installation finished."
echo "Please keep your client password: $password"

