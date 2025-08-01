#!/bin/bash

set -e

echo "CERTBOT_DOMAIN: ${CERTBOT_DOMAIN}"
echo "CERTBOT_VALIDATION: ${CERTBOT_VALIDATION}"

# exit 1

{
    cat <<EOT
update add _acme-challenge.${CHALLENGE_ZONE}. 300 TXT "${CERTBOT_VALIDATION}"
send
EOT
} | nsupdate -k /keys/acme_key # -d

echo "sleep 3"
sleep 3
