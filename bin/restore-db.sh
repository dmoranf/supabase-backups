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
LOCAL_BACKUP_DIR="${BASE_DIR}/backups/${PROJECT_NAME}"

FILE="$1"

if [ -z "${FILE:-}" ]; then
  echo "Uso: restore-db.sh <archivo.dump.age>"
  exit 1
fi

LOCAL_DIR="${LOCAL_BACKUP_DIR}/db"
AGE_FILE="${LOCAL_DIR}/${FILE}"
TMP_PROJECT_DIR="${TMP_DIR}/${PROJECT_NAME}"
TMP_DUMP="${TMP_PROJECT_DIR}/restore.dump"

mkdir -p "$TMP_PROJECT_DIR"

if [ ! -f "$AGE_FILE" ]; then
  echo "[ERROR] Backup no encontrado: $AGE_FILE"
  exit 1
fi

age -d -i "$AGE_PRIVATE_KEY_FILE" -o "$TMP_DUMP" "$AGE_FILE"

pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  --disable-triggers \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$PGUSER" \
  -d "$PGDATABASE" \
  "$TMP_DUMP"

rm "$TMP_DUMP"

echo "[RESTORE] DB restaurada correctamente"