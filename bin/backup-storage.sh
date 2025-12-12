#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Supabase Storage Backup (S3-compatible via rclone)
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Configuración global
# -----------------------------------------------------------------------------
source "${SCRIPT_DIR}/../config/global.env"

# -----------------------------------------------------------------------------
# Configuración del proyecto
# -----------------------------------------------------------------------------
if [ -z "${SUPABASE_BACKUP_ENV:-}" ]; then
  echo "[ERROR] SUPABASE_BACKUP_ENV no definida"
  exit 1
fi

source "$SUPABASE_BACKUP_ENV"

# -----------------------------------------------------------------------------
# Validaciones
# -----------------------------------------------------------------------------
: "${PROJECT_NAME:?PROJECT_NAME no definido}"
: "${LOCAL_BACKUP_DIR:?LOCAL_BACKUP_DIR no definido}"
: "${AGE_PUBLIC_KEY_FILE:?AGE_PUBLIC_KEY_FILE no definido}"

command -v rclone >/dev/null || { echo "[ERROR] rclone no instalado"; exit 1; }
command -v age >/dev/null || { echo "[ERROR] age no instalado"; exit 1; }
command -v tar >/dev/null || { echo "[ERROR] tar no instalado"; exit 1; }

# -----------------------------------------------------------------------------
# Fechas y rutas
# -----------------------------------------------------------------------------
DATE="$(date +%F)"
TS="$(date +%H%M%S)"

TMP_PROJECT_DIR="${TMP_DIR}/${PROJECT_NAME}/storage"
DATA_DIR="${TMP_PROJECT_DIR}/data"

ARCHIVE="${PROJECT_NAME}_storage_${DATE}_${TS}.tar.gz"
ENCRYPTED="${ARCHIVE}.age"

LOCAL_DIR="${LOCAL_BACKUP_DIR}/storage"
LOCAL_FILE="${LOCAL_DIR}/${ENCRYPTED}"

mkdir -p "$DATA_DIR" "$LOCAL_DIR" "$LOG_DIR"

echo "[STORAGE] Backup S3 iniciado ${DATE} ${TS}" >> "$LOG_FILE"

# -----------------------------------------------------------------------------
# 1. Sync completo desde Supabase S3
# -----------------------------------------------------------------------------
rclone sync \
  supabase-s3: \
  "$DATA_DIR" \
  --fast-list \
  --transfers 8 \
  --checkers 8 \
  --log-file "$LOG_FILE" \
  --log-level INFO

# -----------------------------------------------------------------------------
# 2. Empaquetar
# -----------------------------------------------------------------------------
tar -czf "${TMP_PROJECT_DIR}/${ARCHIVE}" -C "$DATA_DIR" .

# -----------------------------------------------------------------------------
# 3. Cifrar
# -----------------------------------------------------------------------------
age -r "$(cat "$AGE_PUBLIC_KEY_FILE")" \
  -o "${TMP_PROJECT_DIR}/${ENCRYPTED}" \
  "${TMP_PROJECT_DIR}/${ARCHIVE}"

# -----------------------------------------------------------------------------
# 4. Copia local
# -----------------------------------------------------------------------------
cp "${TMP_PROJECT_DIR}/${ENCRYPTED}" "$LOCAL_FILE"

# -----------------------------------------------------------------------------
# 5. Limpieza
# -----------------------------------------------------------------------------
rm -rf "$DATA_DIR" \
       "${TMP_PROJECT_DIR:?}/${ARCHIVE}" \
       "${TMP_PROJECT_DIR:?}/${ENCRYPTED}"

echo "[STORAGE] Backup S3 finalizado correctamente" >> "$LOG_FILE"