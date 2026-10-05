#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/global.env"

# Sin SUPABASE_BACKUP_ENV: rotar todos los proyectos (uso desde cron)
if [ -z "${SUPABASE_BACKUP_ENV:-}" ]; then
  FAILED=0
  for ENV_FILE in "${BASE_DIR}/config/projects/"*.env; do
    [ -e "$ENV_FILE" ] || continue
    PROJECT_ID=$(basename "$ENV_FILE" .env)
    echo "[ROTATE] Proyecto: $PROJECT_ID"
    SUPABASE_BACKUP_ENV="$ENV_FILE" bash "${BIN_DIR}/rotate-backup.sh" || {
      FAILED=1
      echo "[ERROR] Rotación fallida: $PROJECT_ID"
      bash "${BIN_DIR}/alert.sh" "ERROR" "$PROJECT_ID" "Rotación FALLIDA" || true
    }
  done
  exit "$FAILED"
fi
source "$SUPABASE_BACKUP_ENV"

# Derived paths (Inline Logic)
LOG_FILE="${LOG_DIR}/${PROJECT_NAME}.log"

mkdir -p "$LOG_DIR"

has_remote() {
  command -v rclone >/dev/null 2>&1 \
    && [ -n "${RCLONE_REMOTE:-}" ] \
    && rclone listremotes 2>/dev/null | grep -q "^${RCLONE_REMOTE%%:*}:"
}

echo "[ROTATE] Limpieza iniciada" >> "$LOG_FILE"

# Local
bash "${BIN_DIR}/rotate-local.sh"
echo "[ROTATE] Limpieza local OK (> ${LOCAL_RETENTION_DAYS}d)" >> "$LOG_FILE"

# Remoto (solo si hay remoto, ruta base y retención configurados)
if ! has_remote; then
  echo "[INFO] Remoto no configurado, se omite rotación remota" >> "$LOG_FILE"
elif [ -z "${RCLONE_BASE_PATH:-}" ] || [ -z "${RETENTION_DAYS:-}" ]; then
  echo "[WARN] RCLONE_BASE_PATH o RETENTION_DAYS no definidos, se omite rotación remota" >> "$LOG_FILE"
else
  for SUBDIR in db storage; do
    REMOTE_PATH="$RCLONE_REMOTE/$RCLONE_BASE_PATH/$SUBDIR"
    # El directorio puede no existir todavía en el remoto
    rclone lsf "$REMOTE_PATH" >/dev/null 2>&1 || continue
    rclone delete "$REMOTE_PATH" --min-age "${RETENTION_DAYS}d"
    echo "[ROTATE] Limpieza remota OK: $SUBDIR (> ${RETENTION_DAYS}d)" >> "$LOG_FILE"
  done
fi

echo "[ROTATE] Limpieza finalizada" >> "$LOG_FILE"
