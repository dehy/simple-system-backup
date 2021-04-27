# dehy's Simple System Backup

[![CI](https://github.com/dehy/simple-system-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/dehy/simple-system-backup/actions/workflows/ci.yml)

Leveraging [Restic](https://github.com/restic/restic), these scripts for Bash (Linux) and Powershell (Windows) automate system backups

## Installation

For Linux, you can use the `install.sh` script to help you configuration the script. It will ask you the mandatory questions. It typically automates the steps described in the Usage section.

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

## Tests

You can launch test with `bash tests/test-install.sh`.
You will need Docker, as it launch a temporary minio instance for s3 testing.

## Contributing

Feel free to create issues or submit a PR!

## License

MIT