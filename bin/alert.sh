#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/global.env"

LEVEL="$1"      # INFO | WARN | ERROR
PROJECT="$2"
MESSAGE="$3"

if [ "${ALERT_TELEGRAM_ENABLED:-false}" = true ]; then
  curl -s -X POST "https://api.telegram.org/bot${ALERT_TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${ALERT_TELEGRAM_CHAT_ID}" \
    -d text="[$LEVEL] [$PROJECT] $MESSAGE" \
    >/dev/null
fi