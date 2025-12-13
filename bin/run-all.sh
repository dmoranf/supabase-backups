#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/global.env"

# Parse arguments
MODE="db" # default
STRATEGY_ARGS=""

# Helper to print usage
usage() {
  echo "Uso: $0 [--db | --storage | --all] [--full | --incremental]"
  exit 1
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --db) MODE="db" ;;
    --storage) MODE="storage" ;;
    --all) MODE="all" ;;
    --full|--incremental) STRATEGY_ARGS="${STRATEGY_ARGS} $1" ;;
    --help|-h) usage ;;
    *) echo "[ERROR] Parámetro desconocido: $1"; usage ;;
  esac
  shift
done

echo "[ORCHESTRATOR] Iniciando backup modo: $MODE"

for ENV_FILE in "${BASE_DIR}/config/projects/"*.env; do
  PROJECT_ID=$(basename "$ENV_FILE" .env)
  
  # --- DB Backup ---
  if [ "$MODE" == "db" ] || [ "$MODE" == "all" ]; then
    (
      export SUPABASE_BACKUP_ENV="$ENV_FILE"
      "${BIN_DIR}/backup-db.sh"
    ) && {
      "${BIN_DIR}/alert.sh" "INFO" "$PROJECT_ID" "Backup DB OK"
    } || {
      "${BIN_DIR}/alert.sh" "ERROR" "$PROJECT_ID" "Backup DB FALLIDO"
    }
  fi

  # --- Storage Backup ---
  if [ "$MODE" == "storage" ] || [ "$MODE" == "all" ]; then
    (
      export SUPABASE_BACKUP_ENV="$ENV_FILE"
      "${BIN_DIR}/backup-storage.sh" $STRATEGY_ARGS
    ) && {
      "${BIN_DIR}/alert.sh" "INFO" "$PROJECT_ID" "Backup Storage OK"
    } || {
      "${BIN_DIR}/alert.sh" "ERROR" "$PROJECT_ID" "Backup Storage FALLIDO"
    }
  fi

done