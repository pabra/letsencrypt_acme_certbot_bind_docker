#!/bin/bash

set -e

echo "delete validation ${CERTBOT_VALIDATION} for domain ${CERTBOT_DOMAIN}"

{
    cat <<EOT
update delete _acme-challenge.${CHALLENGE_ZONE}. TXT "${CERTBOT_VALIDATION}"
send
EOT
} | nsupdate -k /keys/acme_key # -d

echo "sleep 3"
sleep 3
