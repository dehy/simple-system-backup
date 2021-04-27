#!/bin/sh

set -eu
if [ "${DEBUG:-}" = "true" ]; then
    set -x
fi

INSTALL_SCRIPT_DIR=$(dirname $0)
DEFAULT_RESTIC_VERSION="0.12.0"

SSB_VERSION=$(cat ${INSTALL_SCRIPT_DIR}/VERSION)
DIR_NAME="simple-system-backup"
INSTALLATION_PATH="/opt/${DIR_NAME}"

# Prerequisite: restic
RESTIC_BIN="$(which restic || true)"
INSTALL_RESTIC=${INSTALL_RESTIC:-}
echo -n "[I] Searching for restic binary in PATH: "
if [ "$RESTIC_BIN" = "" ]; then
    echo "not found"
else
    echo "found at $RESTIC_BIN ($($RESTIC_BIN version))"
    if [ -z "${INSTALL_RESTIC}" ]; then
        INSTALL_RESTIC="n"
    fi
fi
if [ "$INSTALL_RESTIC" != "y" -a "$INSTALL_RESTIC" != "Y" ]; then
    read -p "[?] Download and install restic binary from github? [Y/n]" INSTALL_RESTIC
    INSTALL_RESTIC=${INSTALL_RESTIC:-"Y"}
fi
if [ "$INSTALL_RESTIC" = "Y" -o "$INSTALL_RESTIC" = "y" ]; then
    FOUND_OPERATING_SYSTEM=$(uname -o)
    if [ "${FOUND_OPERATING_SYSTEM}" = "GNU/Linux" -o "${FOUND_OPERATING_SYSTEM}" = "Linux" ]; then
        OPERATING_SYSTEM="linux"
    fi
    if [ -z "${OPERATING_SYSTEM:-}" ]; then
        echo "[E] Unsupported operating system: $FOUND_OPERATING_SYSTEM"
        exit 1
    fi
    FOUND_HARDWARE_PLATFORM=$(uname -m)
    if [ "${FOUND_HARDWARE_PLATFORM}" = "x86_64" ]; then
        HARDWARE_PLATFORM="amd64"
    fi
    if [ -z "${OPERATING_SYSTEM:-}" ]; then
        echo "[E] Unsupported hardware platform: $FOUND_HARDWARE_PLATFORM"
        exit 1
    fi
    echo "[I] Hardware platform found: ${HARDWARE_PLATFORM}"
    if [ -z "${RESTIC_VERSION:-}" ]; then
        read -p "[?] Restic version to download [$DEFAULT_RESTIC_VERSION]:" RESTIC_VERSION
        RESTIC_VERSION=${RESTIC_VERSION:-"$DEFAULT_RESTIC_VERSION"}
    fi
    TMP_RESTIC_DOWNLOAD_DIR=$(mktemp -d)
    curl -s -L -o "$TMP_RESTIC_DOWNLOAD_DIR/restic.bz2" https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_${OPERATING_SYSTEM}_${HARDWARE_PLATFORM}.bz2
    bunzip2 "$TMP_RESTIC_DOWNLOAD_DIR/restic.bz2"
    mv -i "$TMP_RESTIC_DOWNLOAD_DIR/restic" /usr/local/bin/restic
    chmod +x /usr/local/bin/restic

    echo "[I] Restic installed at /usr/local/bin/restic"
else
    echo "[E] Cannot continue if restic is not installed."
    exit 1
fi


#GITHUB_ARCHIVE_NAME="${DIR_NAME}.tar.gz"
#DOWNLOADED_ARCHIVE_PATH="/tmp/${GITHUB_ARCHIVE_NAME}"

#curl -s -o "${DOWNLOADED_ARCHIVE_PATH}" -L https://github.com/dehy/simple-system-backup/archive/refs/tags/${SSB_VERSION}.tar.gz
#tar xf "${DOWNLOADED_ARCHIVE_PATH}" -C /opt/
mkdir -p "${INSTALLATION_PATH}/"

# If a config file is present, load it
if [ -r "${INSTALLATION_PATH}/backuprc" ]; then
    echo "[I] Found a previous backuprc file. Backuping and loading it."
    # Make a backup
    cp "${INSTALLATION_PATH}/backuprc" "${INSTALLATION_PATH}/backuprc.$(date +%Y%m%d%H%M%S)"
    . "${INSTALLATION_PATH}/backuprc"
fi

cp -R "${INSTALL_SCRIPT_DIR}"/* "${INSTALLATION_PATH}/"

if [ -z "${AWS_ENDPOINT:-}" ]; then
    read -p "[?] S3 Endpoint (ie. s3.eu-west-3.amazonaws.com): " AWS_ENDPOINT
fi
if [ -z "${AWS_DEFAULT_REGION:-}" ]; then
    read -p "[?] S3 Region (ie. eu-west-3): " AWS_DEFAULT_REGION
fi
if [ -z "${AWS_BUCKET:-}" ]; then
    read -p "[?] S3 Bucket (ie. restic-backups): " AWS_BUCKET
fi
if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
    read -p "[?] S3 Access Key: " AWS_ACCESS_KEY_ID
fi
if [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    read -p "[?] S3 Secret Key: " AWS_SECRET_ACCESS_KEY
fi
if [ -z "${BACKUPED_DIRS:-}" ]; then
    read -p "[?] Directories to backup (separate with spaces): " BACKUPED_DIRS
fi

if [ -z "${RESTIC_PASSWORD:-}" ]; then
    RESTIC_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
fi
# TODO add a warning if password is too unsecure

sed \
    -e "s/SAMPLE_KEY_ID/${AWS_ACCESS_KEY_ID}/g" \
    -e "s/SAMPLE_SECRET_KEY/${AWS_SECRET_ACCESS_KEY}/g" \
    -e "s/s3.eu-west-3.amazonaws.com/${AWS_ENDPOINT}/g" \
    -e "s/eu-west-3/${AWS_DEFAULT_REGION}/g" \
    -e "s/bucket_name/${AWS_BUCKET}/g" \
    -e "s/nonSecurePassword/${RESTIC_PASSWORD}/g" \
    -e "s&\(BACKUPED_DIRS=\"\).*$&\1${BACKUPED_DIRS}\"&" \
    "${INSTALLATION_PATH}/backuprc.example" > "${INSTALLATION_PATH}/backuprc"

chmod +x "${INSTALLATION_PATH}/backup.sh"
echo "[I] Simple System Backup is installed at ${INSTALLATION_PATH}!"

cat << EOF

 Here is the restic repository password      
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
    read -p "[?] Do you want to initialize restic and perform a first backup? [Y/n] " PERFORM_INIT_BACKUP
    PERFORM_INIT_BACKUP=${PERFORM_INIT_BACKUP:-"Y"}
fi
if [ "$PERFORM_INIT_BACKUP" = "Y" -o "$PERFORM_INIT_BACKUP" = "y" ]; then
    # Init repository
    "${INSTALLATION_PATH}/backup.sh" --init

    # Launch first backup
    "${INSTALLATION_PATH}/backup.sh"

    echo ""
    echo "[I] Well done! Your first backup is done!"
fi

if [ -z "${INSTALL_CRON_DAILY:-}" ]; then
    read -p "[?] Install a /etc/cron.daily script? [Y/n] " INSTALL_CRON_DAILY
    INSTALL_CRON_DAILY=${INSTALL_CRON_DAILY:-"Y"}
fi
if [ "$INSTALL_CRON_DAILY" = "Y" -o "$INSTALL_CRON_DAILY" = "y" ]; then
    ln -s "$INSTALLATION_PATH/backup.sh" /etc/cron.daily/simple-system-backup
    echo ""
    echo "[I] Daily cron installed!"
    ls -l /etc/cron.daily/simple-system-backup
fi