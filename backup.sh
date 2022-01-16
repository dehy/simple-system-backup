#!/usr/bin/env sh

set -eu

CURRENT_DIR=$(dirname $(readlink -f $0))
RESTIC_BIN=$(which restic)

# TODO check backuprc file permission for u=rw,g=,o=
. "$CURRENT_DIR/backuprc"

if [ "$BACKUP_METHOD" = "s3" ]; then
    export RESTIC_REPOSITORY="s3:${AWS_ENDPOINT}/${AWS_BUCKET}/${BACKUPED_HOST}"
elif [ "$BACKUP_METHOD" = "ftp" -o "$BACKUP_METHOD" = "ftps" ]; then
    export RESTIC_REPOSITORY="${BACKUP_METHOD}://${FTP_USERNAME}:${FTP_PASSWORD}@${FTP_SERVER}/${BACKUPED_HOST}"
else
    echo "[E] Unknown backup method. Aborting."
    exit 1
fi

if [ "${1:-}" = "--init" ]; then
    # Init repository
    $RESTIC_BIN init
    exit 0
fi

if [ "${1:-}" = "--unlock" ]; then
    # Unlock repository
    $RESTIC_BIN unlock
    exit 0
fi

PRE_BACKUP_HOOK_DIR="$CURRENT_DIR/pre-backup.d"
if [ -d "$PRE_BACKUP_HOOK_DIR" ]; then
    echo "Executing Pre Backup scripts"
fi

if [ -r "$CURRENT_DIR/excludes.txt" ]; then
    $EXCLUDE_FILE_PARAM="--exclude-file=\"$CURRENT_DIR/excludes.txt\""
fi

# Backup
$RESTIC_BIN --verbose backup ${EXCLUDE_FILE_PARAM:-} ${BACKUPED_DIRS}

# Cleanup
# TODO make these values dynamic
$RESTIC_BIN --verbose forget --keep-daily 7 --keep-weekly 4 --keep-monthly 4 --prune
