# PSO Save Backup

Small local backup script for Phantasy Star Online saves.

Technically works for anything, but this was built with PSO and Linux in mind. I assume this will work fine on macOS as well, but I have no idea how if this works on Windows.

It backs up:

- Dreamcast V2 Flycast VMU files
- PSO V2 PC save backup folder
- GameCube V3 Dolphin save folder

Optional S3-compatible object storage upload is supported, but disabled by default.

## Layout

Default backup destination:

```text
$HOME/Games/pso_saves/
├── v2/
│   ├── dreamcast/flycast/
│   └── pc/psopeeps/
└── v3/
    └── gamecube/
```

## Configure

Edit `.env` and set your source/destination paths.

```bash
cp .env.example .env
vim .env
```

For local-only backups, leave S3 disabled:

```bash
S3_ENABLED=false
```

For Linode Object Storage or another S3-compatible provider, set:

```bash
S3_ENABLED=true
S3_BUCKET="your-bucket-name"
S3_PREFIX="pso_saves/your-machine"
S3_ENDPOINT_URL="https://your-object-storage-cluster.linodeobjects.com"
S3_REGION="your-object-storage-cluster"
S3_ACCESS_KEY_ID="your-access-key"
S3_SECRET_ACCESS_KEY="your-secret-key"
```

The script runs local backups every time.

When S3 is enabled, it only uploads if at least 24 hours have passed since the previous successful upload.

## pso-backup-saves

After you fill out the `.env` file, install and enable the user systemd timer:

```bash
./scripts/install-user-timer.sh
```

Test the main script manually:

```bash
./backup-pso-saves.sh
```

Check the timer:

```bash
systemctl --user list-timers pso-save-backup.timer
```

Run the service once through systemd:

```bash
systemctl --user start pso-save-backup.service
journalctl --user -u pso-save-backup.service -n 80
```

## Installed user systemd units

The install script copies the timer files to:

```text
$HOME/.config/systemd/user/pso-save-backup.service
$HOME/.config/systemd/user/pso-save-backup.timer
```

The timer runs every 15 minutes.
