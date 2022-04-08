#!/bin/sh

set -e

if [ -z "$DOMAINS" ]; then
  echo "DOMAINS environment variable is not set"
  exit 1;
fi

if [ -z "$SERVICE_NAMES" ]; then
  echo "SERVICE_NAMES environment variable is not set"
  exit 1;
fi

if [ -z "$SERVICE_PORTS" ]; then
  echo "SERVICE_PORTS environment variable is not set"
  exit 1;
fi

use_dummy_certificate() {
  if grep -q "/etc/letsencrypt/live/$1" "/etc/nginx/sites/$1.conf"; then
    echo "Switching Nginx to use dummy certificate for $1"
    sed -i "s|/etc/letsencrypt/live/$1|/etc/nginx/ssl/dummy/$1|g" "/etc/nginx/sites/$1.conf"
  fi
}

use_lets_encrypt_certificate() {
  if grep -q "/etc/nginx/ssl/dummy/$1" "/etc/nginx/sites/$1.conf"; then
    echo "Switching Nginx to use Let's Encrypt certificate for $1"
    sed -i "s|/etc/nginx/ssl/dummy/$1|/etc/letsencrypt/live/$1|g" "/etc/nginx/sites/$1.conf"
  fi
}

reload_nginx() {
  echo "Reloading Nginx configuration"
  nginx -s reload
}

wait_for_lets_encrypt() {
  until [ -d "/etc/letsencrypt/live/$1" ]; do
    echo "Waiting for Let's Encrypt certificates for $1"
    sleep 5s & wait ${!}
  done
  use_lets_encrypt_certificate "$1"
  reload_nginx
}

if [ ! -f /etc/nginx/ssl/ssl-dhparams.pem ]; then
  openssl dhparam -out /etc/nginx/ssl/ssl-dhparams.pem 2048
fi

i=0
while [ "$i" -le ${#DOMAINS[@]} ]; do
  service_name=${SERVICE_NAMES[$i]}
  service_port=${SERVICE_PORTS[$i]}
  if [ ! -f "/etc/nginx/sites/$domain.conf" ]; then
    echo "Creating Nginx configuration file /etc/nginx/sites/$domain.conf"
    sed "s/\${domain}/$domain/g" /customization/site.conf.tpl > "/etc/nginx/sites/$domain.conf"
    sed "s/\${service_name}/$service_name/g" /customization/site.conf.tpl > "/etc/nginx/sites/$domain.conf"
    sed "s/\${service_port}/$service_port/g" /customization/site.conf.tpl > "/etc/nginx/sites/$domain.conf"
    echo `cat "/etc/nginx/sites/$domain.conf"`
  fi

  if [ ! -f "/etc/nginx/ssl/dummy/$domain/fullchain.pem" ]; then
    echo "Generating dummy ceritificate for $domain"
    mkdir -p "/etc/nginx/ssl/dummy/$domain"
    printf "[dn]\nCN=${domain}\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:$domain, DNS:www.$domain\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth" > openssl.cnf
    openssl req -x509 -out "/etc/nginx/ssl/dummy/$domain/fullchain.pem" -keyout "/etc/nginx/ssl/dummy/$domain/privkey.pem" \
      -newkey rsa:2048 -nodes -sha256 \
      -subj "/CN=${domain}" -extensions EXT -config openssl.cnf
    rm -f openssl.cnf
  fi

  if [ ! -d "/etc/letsencrypt/live/$domain" ]; then
    use_dummy_certificate "$domain"
    wait_for_lets_encrypt "$domain" &
  else
    use_lets_encrypt_certificate "$domain"
  fi
  
  i=$(( i + 1 ))
done

exec nginx -g "daemon off;"
