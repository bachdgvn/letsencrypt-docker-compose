upstream ${service_name} {
  server ${service_name}:${service_port};
}

server {
    listen 80;

    server_name ${domain} www.${domain};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot/${domain};
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen       443 ssl;
    server_name  ${domain} www.${domain};

    ssl_certificate /etc/nginx/ssl/dummy/${domain}/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/dummy/${domain}/privkey.pem;

    include /etc/nginx/options-ssl-nginx.conf;

    ssl_dhparam /etc/nginx/ssl/ssl-dhparams.pem;

    include /etc/nginx/hsts.conf;

     location / {
        proxy_pass http://${service_name};
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
