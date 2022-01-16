#!/usr/bin/env sh

set -eu

CURRENT_DIR=$(dirname $(readlink -f $0))
RESTIC_BIN=$(which restic)
BACKUPRC_FILE="$CURRENT_DIR/backuprc"

if [ $(stat -c %a "$BACKUPRC_FILE") != 600 ]; then
    echo "[E] Backuprc file persmissions are incorrect. It should be 600."
    exit 1
fi
if [ $(stat -c %u "$BACKUPRC_FILE") != 0 -o $(stat -c %g "$BACKUPRC_FILE") != 0 ]; then
    echo "[E] Backuprc file ownership is incorrect. It should be owned by user and group 'root'."
    exit 1
fi

. "$BACKUPRC_FILE"

if [ -z "${RESTIC_REPOSITORY:-}" ]; then
    echo "[E] Missing backup repository information. Did you source the \`backuprc\` file?"
    exit 1
fi

if [ "${1:-}" = "--init" ]; then    # Init repository
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
