ARG BASE_IMAGE=
FROM ${BASE_IMAGE}

ARG BIND_VERSION=

RUN apk add --no-cache bind=${BIND_VERSION} bind-tools=${BIND_VERSION}

VOLUME ["/var/bind/keys"]

HEALTHCHECK --interval=5s --timeout=3s --retries=10 \
    CMD dig 100.IN-ADDR.ARPA @127.0.0.1

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]

CMD ["named", "-c", "/etc/bind/named.conf", "-g", "-u", "named"]
