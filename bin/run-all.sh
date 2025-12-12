#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/global.env"

for ENV_FILE in "${BASE_DIR}/config/projects/"*.env; do
  PROJECT_ID=$(basename "$ENV_FILE" .env)

  (
    export SUPABASE_BACKUP_ENV="$ENV_FILE"
    "${BIN_DIR}/backup-db.sh"
  ) && {
    "${BIN_DIR}/alert.sh" "INFO" "$PROJECT_ID" "Backup DB OK"
  } || {
    "${BIN_DIR}/alert.sh" "ERROR" "$PROJECT_ID" "Backup DB FALLIDO"
  }
done