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
LOCAL_BACKUP_DIR="${BASE_DIR}/backups/${PROJECT_NAME}"

for SUBDIR in db storage; do
  [ -d "${LOCAL_BACKUP_DIR}/${SUBDIR}" ] || continue
  find "${LOCAL_BACKUP_DIR}/${SUBDIR}" \
    -type f \
    -name "*.age" \
    -mtime +"${LOCAL_RETENTION_DAYS}" \
    -delete
done
