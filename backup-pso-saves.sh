#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: missing env file: $ENV_FILE" >&2
  exit 1
fi

source "$ENV_FILE"

: "${S3_ENABLED:=false}"
: "${S3_MIN_SECONDS_BETWEEN_UPLOADS:=86400}"
: "${S3_STATE_FILE:=$SCRIPT_DIR/.last_s3_upload_epoch}"

warn() {
  echo "WARNING: $*" >&2
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

is_true() {
  case "${1,,}" in
    true | yes | y | 1 | on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

copy_tree_contents() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [[ ! -d "$src" ]]; then
    warn "$label source directory missing: $src"
    return 0
  fi

  mkdir -p -- "$dst"
  cp -a -- "$src"/. "$dst"/
  echo "Backed up $label -> $dst"
}

copy_flycast_vmus() {
  local files=(
    "vmu_save_A1.bin"
    "vmu_save_A2.bin"
    "vmu_save_B1.bin"
    "vmu_save_B2.bin"
    "vmu_save_C1.bin"
    "vmu_save_C2.bin"
    "vmu_save_D1.bin"
    "vmu_save_D2.bin"
  )

  if [[ ! -d "$FLYCAST_SOURCE" ]]; then
    warn "Flycast source directory missing: $FLYCAST_SOURCE"
    return 0
  fi

  mkdir -p -- "$FLYCAST_DEST"

  for file in "${files[@]}"; do
    if [[ -f "$FLYCAST_SOURCE/$file" ]]; then
      cp -a -- "$FLYCAST_SOURCE/$file" "$FLYCAST_DEST"/
      echo "Backed up Flycast VMU: $file"
    else
      warn "Flycast VMU missing: $FLYCAST_SOURCE/$file"
    fi
  done
}

s3_upload_due() {
  local now
  local last
  local elapsed

  now="$(date +%s)"
  last="0"

  if [[ -f "$S3_STATE_FILE" ]]; then
    last="$(<"$S3_STATE_FILE")"

    if [[ ! "$last" =~ ^[0-9]+$ ]]; then
      warn "Invalid S3 state file contents; forcing upload: $S3_STATE_FILE"
      last="0"
    fi
  fi

  elapsed=$((now - last))

  if ((elapsed >= S3_MIN_SECONDS_BETWEEN_UPLOADS)); then
    return 0
  fi

  echo "S3 upload skipped; last upload was $elapsed seconds ago."
  return 1
}

run_s3_upload() {
  is_true "$S3_ENABLED" || {
    echo "S3 upload disabled."
    return 0
  }

  command -v aws >/dev/null 2>&1 || die "S3_ENABLED=true but aws CLI was not found"

  [[ -n "${S3_BUCKET:-}" ]] || die "S3_BUCKET is not set"
  [[ -n "${S3_ENDPOINT_URL:-}" ]] || die "S3_ENDPOINT_URL is not set"
  [[ -n "${S3_REGION:-}" ]] || die "S3_REGION is not set"
  [[ -n "${S3_ACCESS_KEY_ID:-}" ]] || die "S3_ACCESS_KEY_ID is not set"
  [[ -n "${S3_SECRET_ACCESS_KEY:-}" ]] || die "S3_SECRET_ACCESS_KEY is not set"

  s3_upload_due || return 0

  local prefix
  local remote
  local now

  prefix="${S3_PREFIX:-}"
  prefix="${prefix#/}"
  prefix="${prefix%/}"

  if [[ -n "$prefix" ]]; then
    remote="s3://$S3_BUCKET/$prefix/"
  else
    remote="s3://$S3_BUCKET/"
  fi

  echo "Uploading PSO save backup to S3: $remote"

  AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID" \
    AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY" \
    AWS_DEFAULT_REGION="$S3_REGION" \
    aws --endpoint-url "$S3_ENDPOINT_URL" \
    s3 sync "$BACKUP_ROOT/" "$remote" \
    --only-show-errors

  now="$(date +%s)"
  printf '%s\n' "$now" >|"$S3_STATE_FILE"

  echo "S3 upload complete: $(date -Is)"
}

copy_flycast_vmus
copy_tree_contents "$PSOPEEPS_PC_SOURCE" "$PSOPEEPS_PC_DEST" "PSO V2 PC psopeeps"
copy_tree_contents "$DOLPHIN_GC_SOURCE" "$DOLPHIN_GC_DEST" "GameCube Dolphin"

echo "Local PSO save backup complete: $(date -Is)"

run_s3_upload

echo "PSO save backup job complete: $(date -Is)"
