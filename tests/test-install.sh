#!/bin/bash

set -ux

if [ "$(id -u)" == "0" ]; then
    echo "!!! You should not run this script as root"
    exit 1
fi

# Test file
TEST_DIR_TO_BACKUP=$(mktemp -d)
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 > $TEST_DIR_TO_BACKUP/sample.txt

# Test environment variables
export S3_KEY_ID=minioadmin
export S3_SECRET_KEY=minioadmin
export S3_ENDPOINT=ssb_minio:443
export S3_REGION=us-west-1
export S3_BUCKET=ssb-test
export BACKUP_DIRS="$TEST_DIR_TO_BACKUP"

export PERFORM_INIT_BACKUP=y
export INSTALL_CRON_DAILY=n

# Create test s3 server

## https support for minio
## https://docs.min.io/docs/how-to-secure-access-to-minio-server-with-tls#using-open-ssl
TMP_DIR="$(mktemp -d)"
PRIVATE_KEY_PATH="$TMP_DIR/private.key"
OPENSSL_CONF_PATH="$TMP_DIR/openssl.conf"
CERT_PATH="$TMP_DIR/public.crt"
openssl ecparam -genkey -name prime256v1 | openssl ec -out "${PRIVATE_KEY_PATH}"
cat << EOF > "${OPENSSL_CONF_PATH}"
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = FR
ST = VA
L = Somewhere
O = UCOM
OU = IT
CN = ssb_minio

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ssb_minio
EOF
openssl req -new -x509 -nodes -days 730 \
    -key "${PRIVATE_KEY_PATH}" -out "${CERT_PATH}" -config "${OPENSSL_CONF_PATH}"

# Create the minio service
docker network create ssb_net
docker run -d --rm --name ssb_minio --network ssb_net \
    -v "$TMP_DIR:/root/.minio/certs" minio/minio server --address ":443" /data

# Launch the installation and first backup
docker run --rm --network ssb_net -v "$(pwd):/ssb:ro" -v "$TMP_DIR:/tmp/cert:ro" \
    --name ssb_test -v "$TEST_DIR_TO_BACKUP:$TEST_DIR_TO_BACKUP" \
    -e S3_KEY_ID -e S3_SECRET_KEY -e S3_ENDPOINT -e S3_REGION -e S3_BUCKET -e BACKUP_DIRS \
    -e PERFORM_INIT_BACKUP -e INSTALL_CRON_DAILY \
    alpine:latest \
    sh -c "set -eux; apk add restic curl ca-certificates; \
           cp /tmp/cert/public.crt /usr/local/share/ca-certificates/minio.crt; \
           update-ca-certificates; \
           sh /ssb/install.sh;"

RESULT=$?

# TODO check if backup is good by listing/restoring the backup

docker stop ssb_minio
docker network rm ssb_net
rm -rf "${TMP_DIR}"

exit $RESULT