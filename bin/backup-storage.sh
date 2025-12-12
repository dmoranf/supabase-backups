#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/global.env"

if [ -z "${SUPABASE_BACKUP_ENV:-}" ]; then
  echo "[ERROR] SUPABASE_BACKUP_ENV no definida"
  exit 1
fi
source "$SUPABASE_BACKUP_ENV"

# Validaciones
: "${PROJECT_NAME:?}"
: "${LOCAL_BACKUP_DIR:?}"
: "${SUPABASE_URL:?}"
: "${SUPABASE_SERVICE_ROLE_KEY:?}"

DATE=$(date +%F)
TS=$(date +%H%M%S)

TMP_PROJECT_DIR="${TMP_DIR}/${PROJECT_NAME}/storage"
DATA_DIR="${TMP_PROJECT_DIR}/data"

ARCHIVE="${PROJECT_NAME}_storage_${DATE}_${TS}.tar.gz"
ENCRYPTED="${ARCHIVE}.age"

LOCAL_DIR="${LOCAL_BACKUP_DIR}/storage"
LOCAL_FILE="${LOCAL_DIR}/${ENCRYPTED}"

mkdir -p "$DATA_DIR" "$LOCAL_DIR" "$LOG_DIR"

echo "[STORAGE] Backup iniciado ${DATE} ${TS}" >> "$LOG_FILE"

# 1️⃣ Copiar objetos desde Supabase Storage
rclone copy \
  supabase-storage: \
  "$DATA_DIR" \
  --progress \
  --transfers 8

# 2️⃣ Empaquetar
tar -czf "${TMP_PROJECT_DIR}/${ARCHIVE}" -C "$DATA_DIR" .

# 3️⃣ Cifrar
age -r "$(cat "$AGE_PUBLIC_KEY_FILE")" \
  -o "${TMP_PROJECT_DIR}/${ENCRYPTED}" \
  "${TMP_PROJECT_DIR}/${ARCHIVE}"

# 4️⃣ Copia local
cp "${TMP_PROJECT_DIR}/${ENCRYPTED}" "$LOCAL_FILE"

# Limpieza
rm -rf "$DATA_DIR" "${TMP_PROJECT_DIR:?}/${ARCHIVE}" "${TMP_PROJECT_DIR:?}/${ENCRYPTED}"

echo "[STORAGE] Backup finalizado correctamente" >> "$LOG_FILE"