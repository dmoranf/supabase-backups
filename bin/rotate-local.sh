#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/global.env"

if [ -z "${SUPABASE_BACKUP_ENV:-}" ]; then
  exit 0
fi
source "$SUPABASE_BACKUP_ENV"

find "${LOCAL_BACKUP_DIR}/db" \
  -type f \
  -name "*.age" \
  -mtime +"${LOCAL_RETENTION_DAYS}" \
  -delete