#!/bin/bash

set -e

mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/lluciani.42.fr.key \
    -out /etc/nginx/ssl/lluciani.42.fr.crt \
    -subj "/C=IT/ST=Italy/L=Rome/O=42/CN=lluciani.42.fr"