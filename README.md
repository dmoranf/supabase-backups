# Supabase Backups (Database + Storage S3)

Sistema **simple, robusto y cifrado** para realizar copias de seguridad de proyectos **Supabase**, cubriendo:

- ✅ Base de datos PostgreSQL (pg_dump)
- ✅ Storage usando **Supabase S3 compatible + rclone**
- ✅ Cifrado con `age`
- ✅ Copias locales
- ✅ Soporte multi-proyecto
- ✅ Remoto opcional por proyecto
- ✅ Limpieza automática (retención)
- ✅ Programación con cron

Este README es **la única documentación del repositorio** y describe el estado final y recomendado.

---

## 1. Requisitos

Linux (Debian / Ubuntu recomendado).

```bash
apt install -y postgresql-client rclone age jq tar
```

---

## 2. Estructura

```text
supabase-backups/
├── bin/
│   ├── backup-db.sh
│   ├── backup-storage.sh
│   └── rotate-backups.sh
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

Solo infraestructura común. **Nada específico de Storage aquí.**

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

Todo lo relativo a Supabase y Storage S3 vive **aquí**.

```bash
#!/usr/bin/env bash

export PROJECT_NAME="Demo"
export ENVIRONMENT="production"

# DB
export PGHOST="db.xxxxx.supabase.co"
export PGPORT="5432"
export PGDATABASE="postgres"
export PGUSER="postgres"
export PGPASSWORD="SUPER_SECRET"

# Paths
export PROJECT_DIR="${BASE_DIR}/backups/${PROJECT_NAME}"
export LOG_FILE="${LOG_DIR}/${PROJECT_NAME}.log"
export LOCAL_BACKUP_DIR="${BASE_DIR}/backups/${PROJECT_NAME}"

# Remoto (opcional)
export RCLONE_BASE_PATH="${PROJECT_NAME}/${ENVIRONMENT}"

# Storage S3 (Supabase)
export SUPABASE_URL="https://xxxx.supabase.co"
export AWS_ACCESS_KEY_ID="SUPABASE_S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="SUPABASE_S3_SECRET_KEY"
export RCLONE_S3_ENDPOINT="https://xxxx.supabase.co/storage/v1/s3"
```

---

## 5. Cifrado (age)

```bash
age-keygen -o backup.key
grep public backup.key > config/backup.pub
chmod 600 backup.key config/backup.pub
```

---

## 6. Supabase Storage S3

En el Dashboard:
**Storage → S3 → Create access key**

Copiar key y secret al `project.env`.

---

## 7. rclone

`~/.config/rclone/rclone.conf`

```ini
[supabase-s3]
type = s3
provider = Other
env_auth = true
region = us-east-1
acl = private
```

Verificar:

```bash
rclone lsd supabase-s3:
```

---

## 8. Backups manuales

```bash
export SUPABASE_BACKUP_ENV=config/projects/demo.env
bin/backup-db.sh
bin/backup-storage.sh
```

---

## 9. Limpieza

```bash
bin/rotate-backups.sh
```

---

## 10. Automatización con cron

Editar crontab:

```bash
crontab -e
```

### 10.1 DB diaria (02:00)

```cron
0 2 * * * cd /opt/supabase-backups && for f in config/projects/*.env; do export SUPABASE_BACKUP_ENV="$f"; bin/backup-db.sh; done >> logs/cron-db.log 2>&1
```

### 10.2 Storage semanal (domingo 03:30)

```cron
30 3 * * 0 cd /opt/supabase-backups && for f in config/projects/*.env; do export SUPABASE_BACKUP_ENV="$f"; bin/backup-storage.sh; done >> logs/cron-storage.log 2>&1
```

### 10.3 Limpieza diaria (04:30)

```cron
30 4 * * * cd /opt/supabase-backups && bin/rotate-backups.sh >> logs/cron-rotate.log 2>&1
```

---

## 11. Restore (manual)

### DB

```bash
age -d -i backup.key demo_db_YYYY-MM-DD.sql.gz.age | gunzip | psql
```

### Storage

```bash
age -d -i backup.key Demo_storage_YYYY-MM-DD_HHMMSS.tar.gz.age | tar -xz
rclone sync data/ supabase-s3:
```

---

## 12. Resumen

- Configuración clara por proyecto
- Storage vía S3 oficial
- Backups cifrados
- Multi-proyecto
- Automatización completa

Diseño **listo para producción**.
