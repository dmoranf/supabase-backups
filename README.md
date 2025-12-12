# Supabase Backups (Database + Storage S3)

Sistema **simple, robusto y cifrado** para realizar copias de seguridad de proyectos **Supabase**, cubriendo:

- ✅ Base de datos PostgreSQL (pg_dump)
- ✅ Storage usando **Supabase S3 compatible + rclone**
- ✅ Cifrado con `age`
- ✅ Copias locales
- ✅ Soporte multi‑proyecto
- ✅ Remoto opcional por proyecto
- ✅ Limpieza automática (retención)
- ✅ Orquestación centralizada con `run-all.sh`
- ✅ Programación con cron

Este README es **la única documentación del repositorio** y describe el estado final y recomendado.

---

## 1. Requisitos

Linux (Debian / Ubuntu recomendado).

```bash
apt install -y postgresql-client rclone age jq tar
```

---

## 2. Estructura real del proyecto

```text
supabase-backups/
├── bin/
│   ├── _bootstrap.sh
│   ├── run-all.sh
│   ├── backup-db.sh
│   ├── restore-db.sh
│   ├── backup-storage.sh
│   ├── rotate-backup.sh
│   ├── rotate-local.sh
│   └── alert.sh
├── config/
│   ├── global.env
│   ├── backup.pub
│   └── projects/
│       └── demo.env
├── backups/
├── logs/
└── tmp/
```

---

## 3. Configuración global (`config/global.env`)

```bash
#!/usr/bin/env bash

export BASE_DIR="/opt/supabase-backups"
export BIN_DIR="${BASE_DIR}/bin"
export LOG_DIR="${BASE_DIR}/logs"
export TMP_DIR="${BASE_DIR}/tmp"

export PG_DUMP_BIN="/usr/lib/postgresql/15/bin/pg_dump"
export LOCAL_RETENTION_DAYS=7

export AGE_PUBLIC_KEY_FILE="${BASE_DIR}/config/backup.pub"

export ALERT_TELEGRAM_ENABLED=false
export ALERT_TELEGRAM_BOT_TOKEN=""
export ALERT_TELEGRAM_CHAT_ID=""

export RCLONE_REMOTE=""
```

---

## 4. Configuración por proyecto (`config/projects/demo.env`)

```bash
#!/usr/bin/env bash

export PROJECT_NAME="Demo"
export ENVIRONMENT="production"

export PGHOST="db.xxxxx.supabase.co"
export PGPORT="5432"
export PGDATABASE="postgres"
export PGUSER="postgres"
export PGPASSWORD="SUPER_SECRET"

export PROJECT_DIR="${BASE_DIR}/backups/${PROJECT_NAME}"
export LOG_FILE="${LOG_DIR}/${PROJECT_NAME}.log"
export LOCAL_BACKUP_DIR="${BASE_DIR}/backups/${PROJECT_NAME}"

export RCLONE_BASE_PATH="${PROJECT_NAME}/${ENVIRONMENT}"

export SUPABASE_URL="https://xxxx.supabase.co"
export AWS_ACCESS_KEY_ID="SUPABASE_S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="SUPABASE_S3_SECRET_KEY"
export RCLONE_S3_ENDPOINT="https://xxxx.supabase.co/storage/v1/s3"
```

---

## 5. Ejecución y cron

### Manual

```bash
export SUPABASE_BACKUP_ENV=config/projects/demo.env
bin/run-all.sh
```

### Cron diario (02:00)

```cron
0 2 * * * cd /opt/supabase-backups && bin/run-all.sh >> logs/cron-run.log 2>&1
```

### Limpieza diaria (04:30)

```cron
30 4 * * * cd /opt/supabase-backups && bin/rotate-backup.sh >> logs/cron-rotate.log 2>&1
```

---

## 6. Restore (manual)

```bash
age -d -i backup.key demo_db_YYYY-MM-DD.sql.gz.age | gunzip | psql
```

```bash
age -d -i backup.key Demo_storage_YYYY-MM-DD_HHMMSS.tar.gz.age | tar -xz
rclone sync data/ supabase-s3:
```

---

## 7. Resumen

- Cron solo llama a `run-all.sh`
- Storage vía S3 oficial
- Configuración clara por proyecto
- Backups cifrados
- Limpieza automática
- Listo para producción
