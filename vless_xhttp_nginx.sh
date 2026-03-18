#!/usr/bin/env bash

set -euxo pipefail

UUID="11111111-1111-1111-1111-111111111111"
DOMAIN="x.example.com"
EMAIL="example@example.com"

apt update
apt upgrade -y
apt autoremove -y --purge
apt install -y curl openssl qrencode gnupg2 ca-certificates lsb-release ubuntu-keyring

curl https://nginx.org/keys/nginx_signing.key |
	gpg --dearmor |
	tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
https://nginx.org/packages/mainline/ubuntu $(lsb_release -cs) nginx" |
	tee /etc/apt/sources.list.d/nginx.list

cat >/etc/apt/preferences.d/99nginx <<EOF
Package: *
Pin: origin nginx.org
Pin: release o=nginx
Pin-Priority: 900
EOF

systemctl stop nginx || true
apt remove -y nginx nginx-common nginx-full nginx-core certbot python3-certbot-nginx || true
apt update
apt upgrade -y
apt autoremove -y --purge
apt install -y nginx certbot python3-certbot-nginx

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
xray version

cat >/usr/local/etc/xray/config.json <<EOF
{
    "log": {
        "loglevel": "warning",
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log"
    },
    "inbounds": [
        {
            "listen": "/dev/shm/xray-xhttp.sock,0666",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$UUID",
                        "flow": ""
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "xhttp",
                "security": "none",
                "xhttpSettings": {
                    "path": "/database",
                    "mode": "stream-one"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF

systemctl enable xray
systemctl restart xray
systemctl status xray --no-pager

cat >/etc/nginx/conf.d/xray.conf <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN;

    location / {
        return 200 'ok';
        add_header Content-Type text/plain;
    }
}
EOF

nginx -t
systemctl reload nginx

certbot --nginx -d "$DOMAIN" \
	--non-interactive \
	--agree-tos \
	--email "$EMAIL" \
	--no-eff-email

cat >/etc/nginx/conf.d/xray.conf <<EOF
server {
    listen 443      ssl http2;
    listen [::]:443 ssl http2;
    listen 443      quic reuseport;
    listen [::]:443 quic reuseport;

    add_header Alt-Svc 'h3=":443"; ma=86400' always;

    server_name $DOMAIN;

    location / {
        return 200 'ok';
        add_header Content-Type text/plain;
    }

    location ^~ /database/ {
        client_max_body_size 0;

        grpc_read_timeout 300s;
        grpc_send_timeout 300s;

        grpc_set_header X-Real-IP       \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        grpc_pass grpc://unix:/dev/shm/xray-xhttp.sock;
    }

    ssl_certificate     /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    include     /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}

server {
    if (\$host = $DOMAIN) {
        return 301 https://\$host\$request_uri;
    }

    listen 80;
    listen [::]:80;

    server_name $DOMAIN;

    return 404;
}
EOF

nginx -t
systemctl reload nginx

curl -I http://127.0.0.1
curl -Ik https://"$DOMAIN"

journalctl -u xray -n 100 --no-pager
tail -n 100 /var/log/nginx/error.log
tail -n 100 /var/log/xray/error.log

URL="vless://$UUID@$DOMAIN:443?security=tls&sni=$DOMAIN&alpn=h3&type=xhttp&path=%2Fdatabase&mode=stream-one&encryption=none&fp=chrome#XHTTP-$DOMAIN-$UUID"

qrencode -t ANSIUTF8 "$URL"
echo "$URL"
