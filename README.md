# dehy's Simple System Backup

Leveraging [Restic](https://github.com/restic/restic), these scripts for Bash (Linux) and Powershell (Windows) automate system backups

## Usage

### Linux

1. Depending on your system, copy `backuprc.example` to `backuprc` and update its content accordingly.
2. Run `./backup.sh --init` to init the backup repository
3. Run `./backup.sh` to launch the first backup
4. Create a cron entry with `ln -s /path/to/backup.sh /etc/cron.daily/backup.sh`

### Windows

1. Depending on your system, copy `config.example.ps1` to `config.ps1` and update its content accordingly.
2. Run `.\backup.ps1 --init` to init the backup repository
3. Run `.\backup.ps1` to launch the first backup
4. Add a scheduled task with command `powershell` and argument `-File C:\Path\To\backup.ps1`