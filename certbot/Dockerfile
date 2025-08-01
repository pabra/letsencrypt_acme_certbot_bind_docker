ARG BASE_IMAGE=
FROM ${BASE_IMAGE}

ARG BIND_VERSION=
ARG CERTBOT_VERSION=

VOLUME ["/keys", "/certs"]

RUN apk add --no-cache python3 bind-tools=${BIND_VERSION} openssl certbot=${CERTBOT_VERSION} bash \
    && sed -i 's/providers = provider_sect/#providers = provider_sect/' /etc/ssl/openssl.cnf

WORKDIR /tmp

RUN mkdir config && chmod 0777 config

COPY entrypoint.sh authenticator.sh cleanup.sh /usr/local/bin/
COPY cli.ini /etc/letsencrypt/cli.ini

ENTRYPOINT ["entrypoint.sh"]

CMD ["renew"]
