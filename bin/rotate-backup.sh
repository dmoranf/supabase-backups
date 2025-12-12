#!/usr/bin/env bash
set -euo pipefail

# Bootstrap
if [ -z "${SUPABASE_BACKUP_ENV:-}" ]; then
  echo "[ERROR] SUPABASE_BACKUP_ENV no está definida"
  exit 1
fi
source "$SUPABASE_BACKUP_ENV"

mkdir -p "$LOG_DIR"

echo "[ROTATE] Limpieza iniciada" >> "$LOG_FILE"

rclone delete \
  "$RCLONE_REMOTE/$RCLONE_BASE_PATH/db" \
  --min-age "${RETENTION_DAYS}d"

rclone delete \
  "$RCLONE_REMOTE/$RCLONE_BASE_PATH/storage" \
  --min-age "${RETENTION_DAYS}d"

echo "[ROTATE] Limpieza finalizada" >> "$LOG_FILE"