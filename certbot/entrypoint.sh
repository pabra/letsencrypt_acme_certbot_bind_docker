#!/bin/bash

set -e
# set -x

certbot() {
    # $1 - acme_server
    # $2 - cmd
    # $3 - csr path
    # $4 - cert path
    local certbot_args=(
        '--logs-dir' './logs'
        '--work-dir' './work'
        '--config-dir' './config'
    )

    case $1 in
    production) : ;;
    *)
        certbot_args+=('--test-cert')
        ;;
    esac

    case $2 in
    show_account) certbot_args+=('show_account' '--non-interactive') ;;
    register)
        certbot_args+=('register' '--force-interactive')
        if [ -n "$ACME_CONTACT" ]; then
            certbot_args+=('-m' "$ACME_CONTACT")
        fi
        ;;
    get_cert)
        certbot_args+=(
            'certonly' '--manual'
            '--non-interactive'
            '--csr' "$3"
            '--cert-path' "$4"
            '--preferred-challenges' 'dns'
            '--manual-auth-hook' 'authenticator.sh'
            '--manual-cleanup-hook' 'cleanup.sh'
        )
        ;;
    *)
        echo "unknown certbot command '$2'" >&2
        ;;
    esac

    if
        /usr/bin/certbot "${certbot_args[@]}" >&2
    then
        echo 'Ok'
    else
        echo 'Err'
    fi
}

pretty_key() {
    # $1 - key path

    openssl pkey -text -in "$1" -noout |
        sed -n \
            -e '/Private-Key:/p'
}

pretty_csr() {
    # $1 - csr path

    openssl req -text -in "$1" -noout |
        sed -n \
            -E '/Modulus:|Signature Value:|([0-9a-f]{2}:)+/!p'
}

pretty_cert() {
    # $1 - cert path

    openssl x509 -text -in "$1" -noout |
        sed -n \
            -e '/Certificate::/p' \
            -e '/    Data:/p' \
            -e '/        Signature Algorithm:/p' \
            -e '/        Issuer:/p' \
            -e '/        Validity/,+2p' \
            -e '/        Subject:/p' \
            -e '/        Subject Public Key Info:/,+2p' \
            -e '/        X509v3 extensions:/p' \
            -e '/            X509v3 Key Usage:/,+1p' \
            -e '/            X509v3 Extended Key Usage:/,+1p' \
            -e '/            X509v3 Subject Alternative Name:/,+1p'
}

ensure_account() {
    local acme_server="$1"
    local res

    res=$(certbot "${acme_server}" 'show_account')

    if [ "$res" = 'Ok' ]; then
        echo "$res"
    else
        res=$(certbot "${acme_server}" 'register')

        if [ "$res" = 'Err' ]; then
            echo 'could not register account' >&2
            echo "$res"
        else
            res=$(certbot "${acme_server}" 'show_account')

            echo "$res"
        fi
    fi
}

ensure_rsa_key() {
    local file_path=$1
    local bits=$2

    if [ -z "$bits" ]; then
        bits=4096
    fi

    if [ ! -e "$file_path" ]; then
        echo "generating new key: '$file_path'"
        openssl genrsa "$bits" >"$file_path"
    else
        echo "key already exists: '$file_path'"
    fi

    pretty_key "$file_path"
}

ensure_domain_config() {
    local config_file="$1"
    local base_name
    base_name=$(basename "$config_file" | sed 's/\.cfg//')
    local csr_file="/certs/${base_name}.csr"
    local tmp_csr=/tmp/csr
    local domain_key_file="/certs/${base_name}.key"
    local common_name
    local alt_names
    local line

    if [ ! -e "$domain_key_file" ] && [ -e "$csr_file" ]; then
        echo "Found CSR '$csr_file' without key '$domain_key_file'. Deleting CSR now."
        unlink "$csr_file"
    fi

    ensure_rsa_key "$domain_key_file"

    if [ -e "$csr_file" ]; then
        echo "CSR file '$csr_file' already exists. Delete it first to generate a new/updated one."
        pretty_csr "$csr_file"
        return 0
    fi

    while read -r line; do
        # ignore empty line
        if [ -z "$line" ]; then
            continue
        fi

        # ignore leading hash (#)
        if [ "$(echo "$line" | cut -c1-1)" = '#' ]; then
            continue
        fi

        if [ -z "$common_name" ]; then
            common_name=$line
        elif [ -z "$alt_names" ]; then
            alt_names="DNS:${common_name},DNS:${line}"
        else
            alt_names="${alt_names},DNS:${line}"
        fi
    done <"$config_file"

    if [ -z "$alt_names" ]; then
        # no alternative names
        echo "Generate new CSR '$csr_file' - CN=${common_name}"

        if openssl req \
            -new \
            -sha256 \
            -key "$domain_key_file" \
            -subj "/CN=${common_name}" \
            >"$tmp_csr"; then
            cp "$tmp_csr" "$csr_file"
            pretty_csr "$csr_file"
            unlink "$tmp_csr"
        fi
    else
        # with alternative names
        echo "Generate new CSR '$csr_file' - CN=${common_name} ${alt_names}"

        if openssl req \
            -new \
            -sha256 \
            -key "$domain_key_file" \
            -subj "/CN=${common_name}" \
            -reqexts SAN \
            -config \
            <(cat /etc/ssl/openssl.cnf \
                <(printf "[SAN]\\nsubjectAltName=%s" "$alt_names")) \
            >"$tmp_csr"; then
            cp "$tmp_csr" "$csr_file"
            pretty_csr "$csr_file"
            unlink "$tmp_csr"
        fi
    fi
}

request_cert() {
    local acme_server="$1"
    local csr_file="$2"
    local base_name
    base_name=$(basename "$csr_file" | sed 's/\.csr//')
    local tmp_cert=/tmp/cert
    local cert_file
    local res

    if [ "$acme_server" = 'production' ]; then
        cert_file="/certs/${base_name}.pem"
    else
        cert_file="/certs/${base_name}.staging.pem"
    fi

    if [ ! -e "$csr_file" ]; then
        echo "Missing CSR file: '$csr_file'"
        exit 1
    fi

    res=$(certbot "$acme_server" 'get_cert' "$csr_file" "$tmp_cert")
    if [ "$res" = 'Ok' ]; then
        cp "$tmp_cert" "$cert_file"
        pretty_cert "$cert_file"
        unlink "$tmp_cert"
    fi
}

do_renew() {
    local acme_server="$1"
    local some_csr_files=false
    local csr_file

    while IFS= read -r -d '' csr_file; do
        some_csr_files=true
        echo "csr_file: '$csr_file'"
        request_cert "$acme_server" "$csr_file"
    done < <(find /certs -name '*.csr' -print0)

    if [ $some_csr_files = false ]; then
        echo 'no sign request files found'
    fi
}

do_prepare() {
    local res
    res=$(ensure_account 'staging')

    if [ "$res" = 'Err' ]; then
        echo 'could not ensure account'
        exit 1
    fi

    local some_cfg_files=false
    local config_file

    while IFS= read -r -d '' config_file; do
        some_cfg_files=true
        echo "config_file: '$config_file'"
        ensure_domain_config "$config_file"
    done < <(find /certs -name '*.cfg' -print0)

    if [ $some_cfg_files = false ]; then
        echo 'no domain config files found'
    fi
}

show_usage() {
    echo "Usage: $0 <prepare | renew | test>"
    exit 1
}

case ${ACME_SERVER:?} in
production | staging) : ;;
*)
    echo "ACME_SERVER must be 'staging' or 'production'."
    exit 1
    ;;
esac

case $1 in
prepare)
    do_prepare "${ACME_SERVER}"
    ;;
renew)
    do_renew "${ACME_SERVER}"
    ;;
test)
    do_prepare 'staging'
    do_renew 'staging'
    ;;
*)
    show_usage
    ;;
esac
