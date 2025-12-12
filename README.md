# Supabase Backups (DB + Storage S3)

<div align="center">

![Status](https://img.shields.io/badge/Status-Stable-brightgreen?style=flat-square)
![Bash](https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL-336791?style=flat-square&logo=postgresql&logoColor=white)
![Supabase](https://img.shields.io/badge/Platform-Supabase-3ECF8E?style=flat-square&logo=supabase&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

**Sistema auto-contenible para realizar copias de seguridad robustas de proyectos Supabase en un VPS Linux.**

[Características](#características-principales) • [Requisitos](#requisitos) • [Estructura](#estructura-del-proyecto) • [Instalación](#configuración) • [Uso](#uso) • [Restauración](#restauración)

</div>

---

## 📋 Características Principales

Este repositorio implementa un sistema completo de backups para Supabase:

- 🗄️ **Base de Datos**: Backup completo de PostgreSQL usando `pg_dump`.
- 📦 **Storage**: Sincronización incremental usando S3 compatible + `rclone`.
- 🔐 **Seguridad**: Cifrado fuerte de todos los backups localmente usando `age`.
- 🧹 **Gestión Automática**: Rotación y limpieza de backups antiguos.
- 🏗️ **Multi-proyecto**: Soporte para múltiples entornos/proyectos en el mismo servidor.
- 🚨 **Alertas**: Notificaciones opcionales vía Telegram.

## ⚠️ Aclaraciones Importantes

> [!IMPORTANT]
> **Endpoint S3 Correcto**:
> Según la documentación oficial, usa siempre este formato: `https://<project-ref>.storage.supabase.co`
>
> ❌ **NO usar**: `https://<project-ref>.supabase.co/storage/v1/s3`

> [!NOTE]
> **Orquestación**:
> - `run-all.sh`: Orquesta **SOLO** backups de Base de Datos.
> - `backup-storage.sh`: Se ejecuta independientemente por proyecto (debido a duración y recursos).

## 🛠 Requisitos

Sistema basado en Debian/Ubuntu con las siguientes herramientas instaladas:

```bash
sudo apt update
sudo apt install -y postgresql-client rclone age jq tar
```

## 📂 Estructura del Proyecto

```mermaid
graph TD
    A[Cron] --> B[run-all.sh]
    A --> C[backup-storage.sh]
    B --> D[backup-db.sh]
    C --> E[rclone sync]
    D --> F[pg_dump]
    F --> G[Cifrado age]
    E --> H[Empaquetado tar + age]
    G --> I[Disk / Local]
    H --> I
```

```text
supabase-backups/
├── bin/
│   ├── run-all.sh              # Orquestador DB (Todos los proyectos)
│   ├── backup-db.sh            # Script backup DB individual
│   ├── backup-storage.sh       # Script backup Storage individual
│   ├── rotate-backup.sh        # Rotación de logs/backups
│   └── alert.sh                # Sistema de alertas
├── config/
│   ├── global.env              # Configuración compartida
│   ├── backup.pub              # Clave pública para cifrado
│   └── projects/               # Configs por proyecto
│       └── demo.env
├── backups/                    # Destino de backups
└── logs/                       # Logs de ejecución
```

## ⚙️ Configuración

### 1. Configuración Global (`config/global.env`)

Define la infraestructura común.

```bash
export BASE_DIR="/root/supabase-backups"
export LOCAL_RETENTION_DAYS=7
export AGE_PUBLIC_KEY_FILE="${BASE_DIR}/config/backup.pub"
export ALERT_TELEGRAM_ENABLED=false
```

### 2. Configuración por Proyecto (`config/projects/demo.env`)

Configuración específica para conectar a Supabase DB y S3.

```bash
export PROJECT_NAME="Demo"
export PGHOST="db.xxxxx.supabase.co"
export PGPASSWORD="SUPER_SECRET"

# Storage S3
export AWS_ACCESS_KEY_ID="clave_id"
export AWS_SECRET_ACCESS_KEY="clave_secreta"
export RCLONE_S3_ENDPOINT="https://<project-ref>.storage.supabase.co"
```

### 3. Cifrado (`age`)

Genera las claves. **Guarda `backup.key` en un lugar seguro (fuera del servidor)**.

```bash
age-keygen -o backup.key
grep public backup.key > config/backup.pub
chmod 600 backup.key config/backup.pub
```

### 4. Rclone (`~/.config/rclone/rclone.conf`)

Configuración mínima para el provider S3 genérico.

```ini
[supabase-s3]
type = s3
provider = Other
env_auth = true
region = us-east-1
acl = private
```

## 🚀 Uso

### Ejecución Manual

| Acción | Comando |
|--------|---------|
| **Backup DB (Todos)** | `bin/run-all.sh` |
| **Backup DB (Uno)** | `export SUPABASE_BACKUP_ENV=config/projects/demo.env && bin/backup-db.sh` |
| **Backup Storage** | `export SUPABASE_BACKUP_ENV=config/projects/demo.env && bin/backup-storage.sh` |

### Automatización (Cron)

Ejemplos recomendados para `/etc/crontab` o `crontab -e`:

```cron
# DB diario a las 02:00
0 2 * * * cd /root/supabase-backups && bin/run-all.sh >> logs/cron-db.log 2>&1

# Storage semanal (Domingos 03:00)
0 3 * * 0 cd /root/supabase-backups && for f in config/projects/*.env; do export SUPABASE_BACKUP_ENV="$f"; bin/backup-storage.sh; done >> logs/cron-storage.log 2>&1

# Limpieza diaria (04:30)
30 4 * * * cd /root/supabase-backups && bin/rotate-backup.sh >> logs/cron-rotate.log 2>&1
```

## 🔄 Restauración

Para restaurar los backups cifrados, necesitas tu clave privada (`backup.key`).

### Base de Datos

```bash
age -d -i backup.key demo_db_YYYY-MM-DD.sql.gz.age | gunzip | psql -h ...
```

### Storage

```bash
# 1. Descifrar y descomprimir
age -d -i backup.key Demo_storage_YYYY-MM-DD.tar.gz.age | tar -xz

# 2. Restaurar con rclone (cuidado, esto sobrescribe)
rclone sync data/ supabase-s3:bucket-name
```
