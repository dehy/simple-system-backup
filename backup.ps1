$ErrorActionPreference = "Stop"
Set-PSDebug -Trace 1

$CURRENT_DIR = Split-Path $MyInvocation.MyCommand.Path -Parent

. $CURRENT_DIR\backuprc.ps1

$env:RESTIC_REPOSITORY  = "$RESTIC_REPOSITORY_PREFIX/$BACKUPED_HOST"

if ($args[0] -eq "--init")
{
    restic --verbose init
    Exit
}

if ($args[0] -eq "--unlock")
{
    restic --verbose unlock
    Exit
}

$PRE_BACKUP_HOOK_DIR = "$CURRENT_DIR\pre-backup.d"
if (Test-Path "$PRE_BACKUP_HOOK_DIR" -PathType Container)
{
    Write-Host "Executing pre-backup scripts"
    Foreach ($PRE_BACKUP_SCRIPT in $(Get-ChildItem -Path "$PRE_BACKUP_HOOK_DIR\*.ps1" -Name))
    {
        & "$PRE_BACKUP_HOOK_DIR\$PRE_BACKUP_SCRIPT"
    }
}

# Backup
Write-Host "Folders to backup: $BACKUPED_DIRS"
restic --verbose backup --exclude-file="$CURRENT_DIR\excludes.txt" --use-fs-snapshot $BACKUPED_DIRS

# Cleanup
restic --verbose forget --keep-daily 7 --keep-monthly 4 --prune

Set-PSDebug -Trace 0
$ErrorActionPreference = "Continue"

Exit
