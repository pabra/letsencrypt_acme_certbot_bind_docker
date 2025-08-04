#!/bin/bash

set -e

echo "add validation ${CERTBOT_VALIDATION} for domain ${CERTBOT_DOMAIN}"

# exit 1

{
    cat <<EOT
update add _acme-challenge.${CHALLENGE_ZONE}. 10 TXT "${CERTBOT_VALIDATION}"
send
EOT
} | nsupdate -k /keys/acme_key # -d

echo "sleep 3"
sleep 3
