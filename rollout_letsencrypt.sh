#! /bin/sh

set -x

EDITOR=vim

pkg install -y letsencrypt.sh openssl
if [ $? -ne 0 ];
then
    exit 1;
fi

cp /usr/local/openssl/openssl.cnf.sample /usr/local/openssl/openssl.cnf
if [ $? -ne 0 ];
then
    exit 1;
fi

pw groupadd -n _letsencrypt -g 443
if [ $? -ne 0 ];
then
    exit 1;
fi

pw useradd -n _letsencrypt -u 443 -g 443 -d /usr/local/etc/letsencrypt.sh -w no -s /nonexistent
if [ $? -ne 0 ];
then
    exit 1;
fi

chown root:_letsencrypt /usr/local/etc/letsencrypt.sh
if [ $? -ne 0 ];
then
    exit 1;
fi

chmod 770 /usr/local/etc/letsencrypt.sh
if [ $? -ne 0 ];
then
    exit 1;
fi

mkdir -p -m 775 /usr/local/www/.well-known/acme-challenge
if [ $? -ne 0 ];
then
    exit 1;
fi

chgrp _letsencrypt /usr/local/www/.well-known/acme-challenge
if [ $? -ne 0 ];
then
    exit 1;
fi

echo -e 'weekly_letsencrypt_enable="YES"\nweekly_letsencrypt_user="_letsencrypt"\nweekly_letsencrypt_deployscript="/usr/local/etc/letsencrypt.sh/deploy.sh"' >> /etc/periodic.conf
if [ $? -ne 0 ];
then
    exit 1;
fi

cp /usr/local/etc/letsencrypt.sh/config.sh.example /usr/local/etc/letsencrypt.sh/config.sh

$EDITOR /usr/local/etc/letsencrypt.sh/domains.txt
if [ $? -ne 0 ];
then
    exit 1;
fi

$EDITOR /usr/local/etc/letsencrypt.sh/config.sh
if [ $? -ne 0 ];
then
    exit 1;
fi

if [ -x /usr/local/sbin/nginx ];
then
    NGINXDIR=/usr/local/etc/nginx/ 
    head -c 48 /dev/urandom > /tmp/nginx_ticketkey
    if [ $? -ne 0 ];
    then
        exit 1;
    fi

    echo -e  '#!/bin/sh\nhead -c 48 /dev/urandom > /tmp/nginx_ticketkey\nnginx -s reload' > ${NGINXDIR}ticket_key.sh && chmod u+x ${NGINXDIR}ticket_key.sh
    if [ $? -ne 0 ];
    then
        exit 1;
    fi

    echo -e  "0 2 * * *  root ${NGINXDIR}ticket_key.sh" >> /etc/crontab && service cron restart
    if [ $? -ne 0 ];
    then
        exit 1;
    fi

    echo -e '
server { # https only
    listen         80;
    server_name    www.example.com;
    return         301 https://$server_name$request_uri;
}

server {
    listen              80;  # only on single server
    listen              443 ssl http2;
    server_name         www.example.com;
    keepalive_timeout   70;

    add_header           Strict-Transport-Security "max-age=15552000; includeSubDomains; preload"; # 180 Tage
    #ssl_certificate     /usr/local/etc/letsencrypt.sh/certs/www.example.com/fullchain.pem;
    #ssl_certificate_key /usr/local/etc/letsencrypt.sh/certs/www.example.com/privkey.pem;
    #ssl_dhparam         /usr/local/etc/letsencrypt.sh/certs/www.example.com/dhparam4096.pem;
    ssl_ecdh_curve      secp384r1;
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers         EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:EECDH+ECDSA:EECDH:EDH+AESGCM:EDH:ECDH+AESGCM:ECDH+AES:ECDH:HIGH:MEDIUM:!RC4:!3DES:!CAMELLIA:!SEED:!aNULL:!MD5:!eNULL:!LOW:!EXP:!DSS:!PSK:!SRP;
    ssl_prefer_server_ciphers on;

    ssl_stapling on;
    #ssl_trusted_certificate /usr/local/etc/letsencrypt.sh/certs/www.example.com/chain.pem;
    ssl_stapling_verify on;

    ssl_session_timeout 10m;
    ssl_session_cache off;
    ssl_session_tickets on;
    ssl_session_ticket_key /tmp/nginx_ticketkey;

    location /.well-known/acme-challenge {
        root /usr/local/www;
    }
    # and the rest of server configuration
    # ...
}
    '
fi


echo -e "run
    cd /usr/local/etc/letsencrypt.sh
    su -m _letsencrypt -c 'bash /usr/local/bin/letsencrypt.sh --cron'";
echo -e "for better Key exchange
    openssl dhparam -outform PEM -out dhparam4096.pem 4096";
