#!/bin/bash

set -e

# genera nginx.conf dal template con le porte del .env
# sostituisce SOLO queste variabili, cosi' $uri, $args ecc. di nginx restano intatte
envsubst '${NGINX_PORT} ${WP_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

exec nginx -g "daemon off;"
