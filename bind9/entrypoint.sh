#!/bin/sh

set -ex

# CHALLENGE_ZONE='example.com example2.com sub.example3.com'
[ -z "${CHALLENGE_ZONE}" ] && echo 'CHALLENGE_ZONE not set' && exit 1
[ -z "${CHALLENGE_NS}" ] && echo 'CHALLENGE_NS not set' && exit 1
[ -z "${TSIG_KEY_NAME}" ] && echo 'TSIG_KEY_NAME not set' && exit 1
[ -z "${TSIG_KEY_ALGORITHM}" ] && echo 'TSIG_KEY_ALGORITHM not set' && exit 1

KEY_FILE="/var/bind/keys/${TSIG_KEY_NAME}"

tsig-keygen -a "$TSIG_KEY_ALGORITHM" "$TSIG_KEY_NAME" > "$KEY_FILE"

cat "$KEY_FILE"

ZONEFILE_CONTENT="
\$TTL 300
@ 300 IN SOA ${CHALLENGE_NS}. root.localhost. (
    1       ; serial
    300     ; refresh
    100     ; retry
    300     ; expire
    600     ; negative caching
)
    NS ${CHALLENGE_NS}.
"
NAMED_CONF="
include \"${KEY_FILE}\";

options {
    directory \"/var/bind\";
    check-names master ignore;
    allow-transfer { none; };
    allow-recursion { any; };
    recursion yes;
    forwarders { 8.8.8.8; 8.8.4.4; };
    querylog yes;
};
"
    # allow-recursion { none; };
    # recursion no;

ZONEFILE=
ZONE=

#    allow-update { 172.16.0.0/12; };
for ZONE in ${CHALLENGE_ZONE}; do
    ZONEFILE="/tmp/$ZONE.zone"
    echo "zone: ${ZONE}"
    NAMED_CONF="$NAMED_CONF""
zone \"${ZONE}\" IN {
    type master;
    file \"${ZONEFILE}\";
    allow-update { key ${TSIG_KEY_NAME}; };
};
"
    echo "$ZONEFILE_CONTENT" > "$ZONEFILE"
    chown named "$ZONEFILE"
done

echo 'conf:'
echo "$NAMED_CONF"
# printf "%s" "$NAMED_CONF"

echo "$NAMED_CONF" > /etc/bind/named.conf
# echo "" > /etc/bind/named.conf

exec "$@"
