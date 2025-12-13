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

find "${LOCAL_BACKUP_DIR}/db" \
  -type f \
  -name "*.age" \
  -mtime +"${LOCAL_RETENTION_DAYS}" \
  -delete