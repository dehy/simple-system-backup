#!/usr/bin/env bash

set -eux

CURRENT_DIR=$(dirname $(readlink -f $0))
RESTIC_BIN=$(which restic)

source "$CURRENT_DIR/backuprc"

export RESTIC_REPOSITORY="${RESTIC_REPOSITORY_PREFIX}/${BACKUPED_HOST}"

if [ "${1:-}" == "--init" ]; then
    # Init repository
    $RESTIC_BIN init
    exit 0
fi

if [ "${1:-}" == "--unlock" ]; then
    # Unlock repository
    $RESTIC_BIN unlock
    exit 0
fi

PRE_BACKUP_HOOK_DIR="$CURRENT_DIR/pre-backup.d"
if [ -d "$PRE_BACKUP_HOOK_DIR" ]; then
    echo "Executing Pre Backup scripts"
fi

# Backup
$RESTIC_BIN --verbose backup --exclude-file="$CURRENT_DIR/excludes.txt" ${BACKUPED_DIRS[*]}

# Cleanup
$RESTIC_BIN --verbose forget --keep-daily 7 --keep-monthly 4 --prune