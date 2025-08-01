#!/bin/bash

set -e

{
    cat <<EOT
update delete _acme-challenge.${CHALLENGE_ZONE}. TXT
send
EOT
} | nsupdate -k /keys/acme_key # -d

echo "sleep 3"
sleep 3
