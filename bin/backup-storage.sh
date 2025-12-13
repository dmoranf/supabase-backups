#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Supabase Storage Backup (S3-compatible via rclone)
###############################################################################

# Parse Args
FULL_BACKUP=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --full) FULL_BACKUP=true ;;
    --incremental) FULL_BACKUP=false ;;
    *) ;; # Ignore unknown args or hand off? For now just ignore extras
  esac
  shift
done

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

# Use persistent cache instead of temp dir
CACHE_DIR="${BASE_DIR}/cache/${PROJECT_NAME}/storage"

TMP_PROJECT_DIR="${TMP_DIR}/${PROJECT_NAME}/storage" # For archive creation
mkdir -p "$TMP_PROJECT_DIR"

ARCHIVE="${PROJECT_NAME}_storage_${DATE}_${TS}.tar.gz"
ENCRYPTED="${ARCHIVE}.age"

LOCAL_DIR="${LOCAL_BACKUP_DIR}/storage"
LOCAL_FILE="${LOCAL_DIR}/${ENCRYPTED}"

mkdir -p "$CACHE_DIR" "$LOCAL_DIR" "$LOG_DIR"

echo "[STORAGE] Backup S3 iniciado ${DATE} ${TS}" >> "$LOG_FILE"

# Logic for Full Backup
if [ "$FULL_BACKUP" = true ]; then
  echo "[STORAGE] Modo FULL seleccionado. Borrando caché previa: $CACHE_DIR" >> "$LOG_FILE"
  rm -rf "$CACHE_DIR"
  mkdir -p "$CACHE_DIR"
fi

# -----------------------------------------------------------------------------
# 1. Sync completo desde Supabase S3 (Incremental to Cache)
# -----------------------------------------------------------------------------
rclone sync \
  supabase-s3: \
  "$CACHE_DIR" \
  --fast-list \
  --transfers 8 \
  --checkers 8 \
  --log-file "$LOG_FILE" \
  --log-level INFO

# -----------------------------------------------------------------------------
# 2. Empaquetar
# -----------------------------------------------------------------------------
# Archive from CACHE_DIR
tar -czf "${TMP_PROJECT_DIR}/${ARCHIVE}" -C "$CACHE_DIR" .

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
rm -rf "${TMP_PROJECT_DIR:?}/${ARCHIVE}" \
       "${TMP_PROJECT_DIR:?}/${ENCRYPTED}"

# NOTE: We DO NOT remove CACHE_DIR

echo "[STORAGE] Backup S3 finalizado correctamente" >> "$LOG_FILE"

# Healthcheck success
if [ -n "${HEALTHCHECK_URL:-}" ]; then
  curl -m 10 -fsS "${HEALTHCHECK_URL}" >/dev/null 2>&1 || true
fi