FROM debian:bookworm

RUN apt-get update -y && apt-get install -y nginx openssl gettext-base \
    && rm -rf /var/lib/apt/lists/*

COPY tools/setup.sh  /setup.sh

RUN chmod +x /setup.sh && /setup.sh

COPY conf/nginx.conf /etc/nginx/nginx.conf.template

COPY tools/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/entrypoint.sh"]
