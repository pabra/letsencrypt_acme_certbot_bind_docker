# What

Let's assume your domain is `example.com` and you want to issue a Let's Encrypt
wildcard certificate for it. Therefor you would need to create a TXT resource
record for `_acme-challenge.example.com`. But you cannot or do not want to give
any ACME client your credentials for DNS server or hoster API.

# prepare host

-   you need a host with a static public IP with `docker` set up and no service
    running on public port 53 - let's assume the host has IP `1.2.3.4`
-   without changing the docker-compose file, we can bind the container just to
    one IP address (v4 or v6) - in this example we stick with `1.2.3.4`
-   you should create an `A` (or `AAAA`) record for this server
    in this example we chose `tmp-ns.example.com` pointing to `1.2.3.4`
-   come up with a zone name you do not run any service under and do not plan to do so
    we will use `acme-challenge-zone.example.com`
-   add a `NS` record for `acme-challenge-zone.example.com` with the value `tmp-ns.example.com`
    to your DNS
-   to get a wildcard certificate for `example.com` you would need to create
    a `TXT` record for `_acme-challenge.example.com`
-   let's delegate this to our newly created zone with a `CNAME` record
    for `_acme-challenge.example.com` pointing to `_acme-challenge.acme-challenge-zone.example.com`
-   for every other domain that you want to get certificates for, create another `CNAME` record
    eg: `_acme-challenge.internal.example2.com` to `_acme-challenge.acme-challenge-zone.example.com`
-   copy/clone this repository to your host `tmp-ns.example.com` (`1.2.3.4`)
-   if you already have an Let's Encrypt acoount key that you want to keep using,
    place it in accounts - a new one will be generated otherwise
-   for each certificate you want to request, create a .cfg file in certs/
-   in these .cfg files empty lines and lines starting with `#` (hash) will be ignored
-   put as many domain names in these .cfg files as that certificate should be valid for
-   the fist domain name will be used as the certificates common name - the following will
    become alternative names
-   for our example, create a file `certs/example.com.cfg` with content:
    ```
    # common name
    example.com
    # alt name
    *.example.com
    ```
-   if you already have an RSA key for `example.com` that you wish to keep, place it
    at `certs/example.com.key` (the name before .key needs to match the name of the .cfg file
    before .cfg)
-   copy `.env.example` in the project root to `.env` and set values accordingly
-   build the docker images initially
    ```bash
    docker compose build --pull
    ```
-   to get the CSR (and maybe missing key files) run in the project root folder:
    ```bash
    docker compose run --no-deps --rm --user "$(id -u):$(id -g)" certbot prepare
    ```
-   to get the certificate for the CSR, run:
    ```bash
    docker compose run --rm --user "$(id -u):$(id -g)" certbot ; docker-compose down --volumes
    ```
    that's also what you need to run to renew your certificate(s)

# Tests

```bash
docker compose run --rm --user "$(id -u):$(id -g)" certbot test ; docker-compose down --volumes
```
