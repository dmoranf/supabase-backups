#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Supabase Storage Backup (REST API)
# - Buckets desde Postgres (storage.buckets)
# - Objetos vía API REST
# - Descarga segura (SERVICE_ROLE_KEY)
# - Tar + age
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
# Validaciones
# -----------------------------------------------------------------------------
: "${PROJECT_NAME:?}"
: "${SUPABASE_URL:?}"
: "${SUPABASE_SERVICE_ROLE_KEY:?}"
: "${LOCAL_BACKUP_DIR:?}"
: "${AGE_PUBLIC_KEY_FILE:?}"

: "${PGHOST:?}"
: "${PGPORT:?}"
: "${PGDATABASE:?}"
: "${PGUSER:?}"
: "${PGPASSWORD:?}"

command -v psql >/dev/null || exit 1
command -v curl >/dev/null || exit 1
command -v jq >/dev/null || exit 1
command -v age >/dev/null || exit 1
command -v tar >/dev/null || exit 1

# -----------------------------------------------------------------------------
# Fechas y paths
# -----------------------------------------------------------------------------
DATE="$(date +%F)"
TS="$(date +%H%M%S)"

TMP_DIR="${TMP_DIR}/${PROJECT_NAME}/storage"
DATA_DIR="${TMP_DIR}/data"

ARCHIVE="${PROJECT_NAME}_storage_${DATE}_${TS}.tar.gz"
ENCRYPTED="${ARCHIVE}.age"

LOCAL_DIR="${LOCAL_BACKUP_DIR}/storage"
LOCAL_FILE="${LOCAL_DIR}/${ENCRYPTED}"

mkdir -p "$DATA_DIR" "$LOCAL_DIR" "$LOG_DIR"

echo "[STORAGE] Backup iniciado ${DATE} ${TS}" >> "$LOG_FILE"

# -----------------------------------------------------------------------------
# 1. Obtener buckets desde Postgres
# -----------------------------------------------------------------------------
echo "[STORAGE] Leyendo buckets desde storage.buckets" >> "$LOG_FILE"

mapfile -t BUCKETS < <(
  psql "host=$PGHOST port=$PGPORT dbname=$PGDATABASE user=$PGUSER password=$PGPASSWORD sslmode=require" \
    -Atc "SELECT name FROM storage.buckets ORDER BY name;" |
  tr -d '\r' | sed '/^[[:space:]]*$/d'
)

[ "${#BUCKETS[@]}" -eq 0 ] && exit 1

# -----------------------------------------------------------------------------
# 2. Descargar objetos bucket por bucket
# -----------------------------------------------------------------------------
for bucket in "${BUCKETS[@]}"; do
  echo "[STORAGE] Bucket: $bucket" >> "$LOG_FILE"

  BUCKET_DIR="${DATA_DIR}/${bucket}"
  mkdir -p "$BUCKET_DIR"

  OFFSET=0
  LIMIT=1000

  while true; do
    RESPONSE="$(curl -fsS \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Content-Type: application/json" \
      -X POST \
      "${SUPABASE_URL}/storage/v1/object/list/${bucket}" \
      -d "{\"limit\":${LIMIT},\"offset\":${OFFSET}}")"

    COUNT="$(echo "$RESPONSE" | jq 'length')"
    [ "$COUNT" -eq 0 ] && break

    echo "$RESPONSE" | jq -r '.[].name' | while read -r OBJECT; do
      DEST="${BUCKET_DIR}/${OBJECT}"
      mkdir -p "$(dirname "$DEST")"

      curl -fsS \
        -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
        "${SUPABASE_URL}/storage/v1/object/${bucket}/${OBJECT}" \
        -o "$DEST"
    done

    OFFSET=$((OFFSET + LIMIT))
  done
done

# -----------------------------------------------------------------------------
# 3. Empaquetar
# -----------------------------------------------------------------------------
tar -czf "${TMP_DIR}/${ARCHIVE}" -C "$DATA_DIR" .

# -----------------------------------------------------------------------------
# 4. Cifrar
# -----------------------------------------------------------------------------
age -r "$(cat "$AGE_PUBLIC_KEY_FILE")" \
  -o "${TMP_DIR}/${ENCRYPTED}" \
  "${TMP_DIR}/${ARCHIVE}"

# -----------------------------------------------------------------------------
# 5. Copia local
# -----------------------------------------------------------------------------
cp "${TMP_DIR}/${ENCRYPTED}" "$LOCAL_FILE"

# -----------------------------------------------------------------------------
# 6. Limpieza
# -----------------------------------------------------------------------------
rm -rf "$DATA_DIR" \
       "${TMP_DIR}/${ARCHIVE}" \
       "${TMP_DIR}/${ENCRYPTED}"

echo "[STORAGE] Backup finalizado correctamente" >> "$LOG_FILE"