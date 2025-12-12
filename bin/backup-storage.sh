#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Backup de Supabase Storage (buckets dinámicos)
# - Descubre buckets vía API
# - Copia cada bucket con rclone
# - Empaqueta + cifra con age
# - Guarda backup local
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Configuración global
# -----------------------------------------------------------------------------
source "${SCRIPT_DIR}/../config/global.env"

# -----------------------------------------------------------------------------
# Configuración de proyecto
# -----------------------------------------------------------------------------
if [ -z "${SUPABASE_BACKUP_ENV:-}" ]; then
  echo "[ERROR] SUPABASE_BACKUP_ENV no definida"
  exit 1
fi

source "$SUPABASE_BACKUP_ENV"

# -----------------------------------------------------------------------------
# Validaciones obligatorias
# -----------------------------------------------------------------------------
: "${PROJECT_NAME:?PROJECT_NAME no definido}"
: "${LOCAL_BACKUP_DIR:?LOCAL_BACKUP_DIR no definido}"
: "${SUPABASE_URL:?SUPABASE_URL no definido}"
: "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY no definido}"
: "${AGE_PUBLIC_KEY_FILE:?AGE_PUBLIC_KEY_FILE no definido}"

command -v rclone >/dev/null || { echo "[ERROR] rclone no instalado"; exit 1; }
command -v jq >/dev/null || { echo "[ERROR] jq no instalado"; exit 1; }
command -v age >/dev/null || { echo "[ERROR] age no instalado"; exit 1; }

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

echo "[STORAGE] Backup iniciado ${DATE} ${TS}" >> "$LOG_FILE"

# -----------------------------------------------------------------------------
# Obtener buckets dinámicamente desde Supabase API
# -----------------------------------------------------------------------------
echo "[STORAGE] Obteniendo lista dinámica de buckets" >> "$LOG_FILE"

mapfile -t BUCKETS < <(
  curl -fsS \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
    "${SUPABASE_URL}/storage/v1/bucket" |
  jq -r '.[].name'
)

if [ "${#BUCKETS[@]}" -eq 0 ]; then
  echo "[STORAGE] ERROR: no se encontraron buckets" >> "$LOG_FILE"
  exit 1
fi

# -----------------------------------------------------------------------------
# Copiar cada bucket
# -----------------------------------------------------------------------------
for bucket in "${BUCKETS[@]}"; do
  echo "[STORAGE] Copiando bucket: ${bucket}" >> "$LOG_FILE"

  rclone copy \
    "supabase-storage:${bucket}" \
    "${DATA_DIR}/${bucket}" \
    --transfers 8 \
    --checkers 8 \
    --create-empty-src-dirs \
    --quiet
done

# -----------------------------------------------------------------------------
# Empaquetar
# -----------------------------------------------------------------------------
tar -czf "${TMP_PROJECT_DIR}/${ARCHIVE}" -C "$DATA_DIR" .

# -----------------------------------------------------------------------------
# Cifrar
# -----------------------------------------------------------------------------
age -r "$(cat "$AGE_PUBLIC_KEY_FILE")" \
  -o "${TMP_PROJECT_DIR}/${ENCRYPTED}" \
  "${TMP_PROJECT_DIR}/${ARCHIVE}"

# -----------------------------------------------------------------------------
# Copia local
# -----------------------------------------------------------------------------
cp "${TMP_PROJECT_DIR}/${ENCRYPTED}" "$LOCAL_FILE"

# -----------------------------------------------------------------------------
# Limpieza
# -----------------------------------------------------------------------------
rm -rf "$DATA_DIR" \
       "${TMP_PROJECT_DIR:?}/${ARCHIVE}" \
       "${TMP_PROJECT_DIR:?}/${ENCRYPTED}"

echo "[STORAGE] Backup finalizado correctamente" >> "$LOG_FILE"