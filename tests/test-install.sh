#!/bin/bash

set -eu

if [ "$(id -u)" == "0" ]; then
    echo "!!! You should not run this script as root"
    exit 1
fi
# Get absolute project dir
cd $(dirname -- "$0")
BASE_DIR=$(dirname $(pwd))
cd - > /dev/null

if [ "${DEBUG:-}" = "true" ]; then
    set -x
fi

# Create test file to backup
TEST_DIR_TO_BACKUP=$(mktemp -d)
RANDOM_CONTENT="$(date +%s) $RANDOM"
echo $RANDOM_CONTENT > $TEST_DIR_TO_BACKUP/sample.txt

# Test environment variables
export BACKUP_METHOD=s3
export BACKUPED_DIRS="$TEST_DIR_TO_BACKUP"
export AWS_ENDPOINT=ssb_minio:443
export AWS_DEFAULT_REGION=us-west-1
export AWS_BUCKET=ssb-test
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin

export INSTALL_RESTIC=y
export RESTIC_VERSION=0.12.0
export PERFORM_INIT_BACKUP=y
export INSTALL_CRON_DAILY=n

# Create test s3 server with minio

## https support for minio
## https://docs.min.io/docs/how-to-secure-access-to-minio-server-with-tls#using-open-ssl
echo "[Test] Generating TLS certificate for S3 test endpoint with minio"
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
echo "[Test] Creating network and minio container"
docker network create ssb_net
docker run -d --rm --name ssb_minio --network ssb_net \
    -v "$TMP_DIR:/root/.minio/certs" minio/minio server --address ":443" /data

# Launch the installation and first backup
echo "[Test] Launching Simple System Backup installation in a container"
docker run --rm --network ssb_net -v "${BASE_DIR}:/ssb:ro" -v "${TMP_DIR}:/tmp/cert:ro" \
    --name ssb_test -v "$TEST_DIR_TO_BACKUP:$TEST_DIR_TO_BACKUP" \
    -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_ENDPOINT -e AWS_DEFAULT_REGION -e AWS_BUCKET -e BACKUPED_DIRS \
    -e INSTALL_RESTIC -e RESTIC_VERSION -e PERFORM_INIT_BACKUP -e INSTALL_CRON_DAILY \
    -e DEBUG \
    alpine:latest \
    sh -c "set -eu; apk add curl ca-certificates; \
           cp /tmp/cert/public.crt /usr/local/share/ca-certificates/minio.crt; \
           update-ca-certificates; \
           sh /ssb/install.sh;"

RESULT=$?

# TODO check if backup is good by listing/restoring the backup

echo "[Test] removing containers and network"
docker stop ssb_minio
docker network rm ssb_net
rm -rf "${TMP_DIR}" "${TEST_DIR_TO_BACKUP}"
echo "[Test] The end!"

exit $RESULT