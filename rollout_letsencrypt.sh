
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

    echo -e  '#!/bin/bash\nhead -c 48 /dev/urandom > /tmp/nginx_ticketkey\nnginx -s reload' > ${NGINXDIR}ticket_key.sh
    if [ $? -ne 0 ];
    then
        exit 1;
    fi

    echo -e  "0 2 * * *  root ${NGINXDIR}ticket_key.sh" >> /etc/crontab && service cron restart
    if [ $? -ne 0 ];
    then
        exit 1;
    fi

    echo -e "
    
    "
fi


echo -e "run
    cd /usr/local/etc/letsencrypt.sh
    su -m _letsencrypt -c 'bash /usr/local/bin/letsencrypt.sh --cron'";
echo -e "for better Key exchange
    openssl dhparam -outform PEM -out dhparam4096.pem 4096";
