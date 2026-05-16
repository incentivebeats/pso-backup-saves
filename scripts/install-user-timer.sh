#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
USER_SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

SERVICE_SRC="$REPO_DIR/timers/pso-save-backup.service"
TIMER_SRC="$REPO_DIR/timers/pso-save-backup.timer"

SERVICE_DST="$USER_SYSTEMD_DIR/pso-save-backup.service"
TIMER_DST="$USER_SYSTEMD_DIR/pso-save-backup.timer"

if [[ ! -f "$SERVICE_SRC" ]]; then
  echo "ERROR: missing service file: $SERVICE_SRC" >&2
  exit 1
fi

if [[ ! -f "$TIMER_SRC" ]]; then
  echo "ERROR: missing timer file: $TIMER_SRC" >&2
  exit 1
fi

if [[ ! -x "$REPO_DIR/backup-pso-saves.sh" ]]; then
  echo "ERROR: backup script is missing or not executable: $REPO_DIR/backup-pso-saves.sh" >&2
  echo "Try: chmod 700 backup-pso-saves.sh" >&2
  exit 1
fi

mkdir -p -- "$USER_SYSTEMD_DIR"

sed \
  -e "s|^WorkingDirectory=.*|WorkingDirectory=$REPO_DIR|" \
  -e "s|^ExecStart=.*|ExecStart=$REPO_DIR/backup-pso-saves.sh|" \
  "$SERVICE_SRC" >|"$SERVICE_DST"

cp -a -- "$TIMER_SRC" "$TIMER_DST"

systemctl --user daemon-reload
systemctl --user enable --now pso-save-backup.timer

echo "Installed user systemd units:"
echo "  $SERVICE_DST"
echo "  $TIMER_DST"
echo
systemctl --user list-timers pso-save-backup.timer
