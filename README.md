# PSO Save Backup

Small local backup script for Phantasy Star Online saves.

Technically works for anything but this was built with PSO in mind.

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
# pso-backup-saves
