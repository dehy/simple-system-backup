#!/bin/sh

set -eux

RESTIC_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

INSTALL_SCRIPT_DIR=$(dirname $0)

VERSION=$(cat ${INSTALL_SCRIPT_DIR}/VERSION)
DIR_NAME="simple-system-backup"
INSTALLATION_PATH="/opt/${DIR_NAME}"

#GITHUB_ARCHIVE_NAME="${DIR_NAME}.tar.gz"
#DOWNLOADED_ARCHIVE_PATH="/tmp/${GITHUB_ARCHIVE_NAME}"

#curl -s -o "${DOWNLOADED_ARCHIVE_PATH}" -L https://github.com/dehy/simple-system-backup/archive/refs/tags/${VERSION}.tar.gz
#tar xf "${DOWNLOADED_ARCHIVE_PATH}" -C /opt/
mkdir -p "${INSTALLATION_PATH}/"
cp -R "${INSTALL_SCRIPT_DIR}"/* "${INSTALLATION_PATH}/"

if [ -z "${S3_ENDPOINT:-}" ]; then
    read -p "S3 Endpoint (ie. s3.eu-west-3.amazonaws.com): " S3_ENDPOINT
fi
if [ -z "${S3_REGION:-}" ]; then
    read -p "S3 Region (ie. eu-west-3): " S3_REGION
fi
if [ -z "${S3_BUCKET:-}" ]; then
    read -p "S3 Bucket (ie. restic-backups): " S3_BUCKET
fi
if [ -z "${S3_KEY_ID:-}" ]; then
    read -p "S3 Access Key: " S3_KEY_ID
fi
if [ -z "${S3_SECRET_KEY:-}" ]; then
    read -p "S3 Secret Key: " S3_SECRET_KEY
fi
if [ -z "${BACKUP_DIRS:-}" ]; then
    read -p "Directories to backup (separate with spaces): " BACKUP_DIRS
fi

sed \
    -e "s/SAMPLE_KEY_ID/${S3_KEY_ID}/g" \
    -e "s/SAMPLE_SECRET_KEY/${S3_SECRET_KEY}/g" \
    -e "s/s3.eu-west-3.amazonaws.com/${S3_ENDPOINT}/g" \
    -e "s/eu-west-3/${S3_REGION}/g" \
    -e "s/bucket_name/${S3_BUCKET}/g" \
    -e "s/nonSecurePassword/${RESTIC_PASSWORD}/g" \
    -e "s&\(BACKUPED_DIRS=\"\).*$&\1${BACKUP_DIRS}\"&" \
    "${INSTALLATION_PATH}/backuprc.example" > "${INSTALLATION_PATH}/backuprc"

chmod +x "${INSTALLATION_PATH}/backup.sh"
echo "Simply System Backup is installed at ${INSTALLATION_PATH}!"
cat << EOF

       Here is the restic password      
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!                                  !!!
!!! ${RESTIC_PASSWORD} !!!
!!!                                  !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!! Save it in a secure place !!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF

if [ -z "${PERFORM_INIT_BACKUP:-}" ]; then
    echo ""
    read -p "Do you want to initialize restic and perform a first backup? [Y/n] " PERFORM_INIT_BACKUP
    PERFORM_INIT_BACKUP=${PERFORM_INIT_BACKUP:-"Y"}
fi
if [ "$PERFORM_INIT_BACKUP" = "Y" -o "$PERFORM_INIT_BACKUP" = "y" ]; then
    # Init repository
    "${INSTALLATION_PATH}/backup.sh" --init

    # Launch first backup
    "${INSTALLATION_PATH}/backup.sh"

    echo ""
    echo "Well done! Your first backup is done!"
fi

if [ -z "${INSTALL_CRON_DAILY:-}" ]; then
    read -p "Install a /etc/cron.daily script? [Y/n] " INSTALL_CRON_DAILY
    INSTALL_CRON_DAILY=${INSTALL_CRON_DAILY:-"Y"}
fi
if [ "$INSTALL_CRON_DAILY" = "Y" -o "$INSTALL_CRON_DAILY" = "y" ]; then
    ln -s "$INSTALLATION_PATH/backup.sh" /etc/cron.daily/simple-system-backup
    echo ""
    echo "Daily cron installed!"
    ls -l /etc/cron.daily/simple-system-backup
fi