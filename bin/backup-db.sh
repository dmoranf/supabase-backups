#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/global.env"

if [ -z "${SUPABASE_BACKUP_ENV:-}" ]; then
  echo "[ERROR] SUPABASE_BACKUP_ENV no definida"
  exit 1
fi
source "$SUPABASE_BACKUP_ENV"

# Derived paths (Inline Logic)
PROJECT_DIR="${BASE_DIR}/backups/${PROJECT_NAME}"
LOG_FILE="${LOG_DIR}/${PROJECT_NAME}.log"
LOCAL_BACKUP_DIR="${BASE_DIR}/backups/${PROJECT_NAME}"

# Healthcheck start
if [ -n "${HEALTHCHECK_URL:-}" ]; then
  curl -m 10 -fsS "${HEALTHCHECK_URL}/start" >/dev/null 2>&1 || true
fi

# Error Handler
handle_error() {
  local exit_code=$?
  local line_number=$1
  echo "[ERROR] Fallo en línea $line_number con código $exit_code" >> "$LOG_FILE"
  "${BIN_DIR}/alert.sh" "ERROR" "$PROJECT_NAME" "Fallo fatal en línea $line_number. Exit code: $exit_code"
  
  if [ -n "${HEALTHCHECK_URL:-}" ]; then
    curl -m 10 -fsS "${HEALTHCHECK_URL}/fail" >/dev/null 2>&1 || true
  fi
}
trap 'handle_error $LINENO' ERR

has_remote() {
  command -v rclone >/dev/null 2>&1 \
    && [ -n "${RCLONE_REMOTE:-}" ] \
    && rclone listremotes 2>/dev/null | grep -q "^${RCLONE_REMOTE%%:*}:"
}

DATE=$(date +%F)
TS=$(date +%H%M%S)

FILENAME="${PROJECT_NAME}_db_${DATE}_${TS}.dump"
ENCRYPTED="${FILENAME}.age"

# TMP is only for encrypted result if we need to upload it
TMP_PROJECT_DIR="${TMP_DIR}/${PROJECT_NAME}"
TMP_ENC="${TMP_PROJECT_DIR}/${ENCRYPTED}"

LOCAL_DIR="${LOCAL_BACKUP_DIR}/db"
LOCAL_FILE="${LOCAL_DIR}/${ENCRYPTED}"

mkdir -p "$TMP_PROJECT_DIR" "$LOCAL_DIR" "$LOG_DIR"

echo "[DB] Backup iniciado ${DATE} ${TS}" >> "$LOG_FILE"

# Streaming: pg_dump -> age -> TMP_ENC (avoids plain dump on disk)
"${PG_DUMP_BIN:-pg_dump}" \
  --format=custom \
  --no-owner \
  --no-privileges \
  | age -r "$(cat "$AGE_PUBLIC_KEY_FILE")" > "$TMP_ENC"

echo "[DB] Copia local: $LOCAL_FILE" >> "$LOG_FILE"
cp "$TMP_ENC" "$LOCAL_FILE"
ls -lh "$LOCAL_FILE" >> "$LOG_FILE"

if has_remote; then
  if rclone copy "$TMP_ENC" "$RCLONE_REMOTE/$RCLONE_BASE_PATH/db/" --checksum; then
    echo "[DB] Subida remota OK" >> "$LOG_FILE"
  else
    echo "[WARN] Fallo subida remota DB" >> "$LOG_FILE"
    "${BIN_DIR}/alert.sh" "WARN" "$PROJECT_NAME" "Fallo subida remota DB"
  fi
else
  echo "[INFO] Remoto no configurado, se omite subida DB" >> "$LOG_FILE"
fi

rm "$TMP_ENC"

echo "[DB] Backup finalizado ${DATE} ${TS}" >> "$LOG_FILE"

# Healthcheck success
if [ -n "${HEALTHCHECK_URL:-}" ]; then
  curl -m 10 -fsS "${HEALTHCHECK_URL}" >/dev/null 2>&1 || true
fi