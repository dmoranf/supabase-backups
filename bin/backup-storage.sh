#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/global.env"

if [ -z "${SUPABASE_BACKUP_ENV:-}" ]; then
  echo "[ERROR] SUPABASE_BACKUP_ENV no definida"
  exit 1
fi
source "$SUPABASE_BACKUP_ENV"

DATE=$(date +%F)
TS=$(date +%H%M%S)

ARCHIVE="${PROJECT_NAME}_storage_${DATE}_${TS}.tar.gz"
ENCRYPTED="${ARCHIVE}.age"

TMP_PROJECT_DIR="${TMP_DIR}/${PROJECT_NAME}/storage"
TMP_ARCHIVE="${TMP_PROJECT_DIR}/${ARCHIVE}"
TMP_ENC="${TMP_PROJECT_DIR}/${ENCRYPTED}"

LOCAL_DIR="${LOCAL_BACKUP_DIR}/storage"
LOCAL_FILE="${LOCAL_DIR}/${ENCRYPTED}"

mkdir -p "$TMP_PROJECT_DIR" "$LOCAL_DIR" "$LOG_DIR"

echo "[STORAGE] Backup iniciado ${DATE} ${TS}" >> "$LOG_FILE"

# ⚠️ TODOO  implementar la descarga real del storage Supabase

tar -czf "$TMP_ARCHIVE" -C "$TMP_PROJECT_DIR" .

age -r "$(cat "$AGE_PUBLIC_KEY_FILE")" \
  -o "$TMP_ENC" \
  "$TMP_ARCHIVE"

rm "$TMP_ARCHIVE"

cp "$TMP_ENC" "$LOCAL_FILE"
echo "[STORAGE] Copia local OK: $LOCAL_FILE" >> "$LOG_FILE"

rm "$TMP_ENC"

echo "[STORAGE] Backup finalizado" >> "$LOG_FILE"