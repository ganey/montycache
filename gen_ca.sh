#!/bin/sh
mkdir -p /etc/nginx/ssl
openssl genrsa -out /etc/nginx/ssl/rootCA.key 4096
openssl req -x509 -new -nodes -key /etc/nginx/ssl/rootCA.key -sha256 -days 3650 -out /etc/nginx/ssl/rootCA.pem 
    -subj "/C=US/ST=State/L=City/O=MontyCache/CN=MontyCache-Root-CA"
