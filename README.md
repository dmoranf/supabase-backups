# Supabase Backups
Sistema multi‑proyecto de copias de seguridad para Supabase (DB + Storage)

Este repositorio proporciona un **sistema completo y funcional** para realizar copias de seguridad de proyectos **Supabase** desde un VPS Linux.

Este README es **la documentación única** del sistema:
- No existe `env.sh`
- Todo se basa en configuración **global** y **por proyecto**
- Los scripts no contienen rutas hardcodeadas

---

## 🎯 Qué hace este sistema

- Backup de PostgreSQL (Supabase)
- Backup de Supabase Storage
- Soporte multi‑proyecto
- Backups locales cifrados siempre
- Backup remoto opcional (cold‑backup)
- Restore manual y seguro
- Alertas automáticas
- Pensado para producción real

---

## 🧱 Estructura del proyecto

```
supabase-backups/
├── bin/
│   ├── backup-db.sh        # Backup PostgreSQL
│   ├── restore-db.sh       # Restore PostgreSQL
│   ├── backup-storage.sh   # Backup Storage
│   ├── rotate-local.sh     # Retención local
│   ├── run-all.sh          # Ejecución multi-proyecto
│   └── alert.sh            # Alertas
├── config/
│   ├── global.env          # Configuración GLOBAL
│   └── projects/           # Configuración POR PROYECTO
│       └── demo.env
├── backups/                # Backups locales cifrados
├── logs/                   # Logs por proyecto
└── tmp/                    # Temporales
```

---

## ⚙️ Requisitos

Sistema:
- Debian / Ubuntu

Paquetes necesarios:

```bash
apt update
apt install -y postgresql-client age rclone curl
```

⚠️ El cliente PostgreSQL **debe coincidir con Supabase**  
(Supabase Cloud usa PostgreSQL 15).

---

## 🔐 Cifrado – Generación de claves

Todos los backups se cifran con **age**.

### 1️⃣ Generar claves

```bash
age-keygen -o backup.key
```

Salida:
```
Public key: age1xxxxxxxxxxxxxxxxxxxxxxxx
```

### 2️⃣ Ubicación de las claves

- Clave privada (NO versionar):
  ```
  /root/secure/backup.key
  ```

- Clave pública:
  ```
  config/backup.pub
  ```

---

## 🧩 Configuración GLOBAL

Archivo: `config/global.env`

```bash
export BASE_DIR="/root/supabase-backups"
export BIN_DIR="${BASE_DIR}/bin"
export LOG_DIR="${BASE_DIR}/logs"
export TMP_DIR="${BASE_DIR}/tmp"

export PG_DUMP_BIN="/usr/lib/postgresql/15/bin/pg_dump"

export AGE_PUBLIC_KEY_FILE="${BASE_DIR}/config/backup.pub"

# Alertas (opcional)
export ALERT_TELEGRAM_ENABLED=false
export ALERT_TELEGRAM_BOT_TOKEN=""
export ALERT_TELEGRAM_CHAT_ID=""

# Backup remoto (opcional)
export RCLONE_REMOTE=""
```

📌 `BASE_DIR` se define **solo aquí**.

---

## 🧩 Configuración POR PROYECTO

Archivo: `config/projects/demo.env`

```bash
export PROJECT_NAME="demo"
export ENVIRONMENT="production"

export PGHOST="db.xxxxx.supabase.co"
export PGPORT="5432"
export PGDATABASE="postgres"
export PGUSER="postgres"
export PGPASSWORD="PASSWORD_REAL"

export LOCAL_BACKUP_DIR="${BASE_DIR}/backups/${PROJECT_NAME}"
export LOG_FILE="${LOG_DIR}/${PROJECT_NAME}.log"

export RCLONE_BASE_PATH="${PROJECT_NAME}/${ENVIRONMENT}"
```

Añadir un proyecto = copiar este archivo.

---

## 🗄️ Backup de Base de Datos

```bash
export SUPABASE_BACKUP_ENV=config/projects/demo.env
bin/backup-db.sh
```

Resultado:
```
backups/demo/db/*.dump.age
```

---

## 🔁 Restore de Base de Datos (manual)

```bash
export SUPABASE_BACKUP_ENV=config/projects/demo.env
export AGE_PRIVATE_KEY_FILE=/root/secure/backup.key

bin/restore-db.sh demo_db_YYYY-MM-DD_HHMMSS.dump.age
```

El restore:
- es explícito
- limpia esquemas
- desactiva triggers
- es seguro para FK circulares

---

## 📦 Backup de Storage

```bash
export SUPABASE_BACKUP_ENV=config/projects/demo.env
bin/backup-storage.sh
```

El método de acceso a Storage depende de tu entorno:
- rclone S3 / WebDAV
- Supabase CLI
- API

---

## 🔁 Multi‑proyecto

```bash
bin/run-all.sh
```

Ejecuta todos los proyectos configurados.

---

## 🧹 Retención local

```bash
bin/rotate-local.sh
```

Elimina backups antiguos según `LOCAL_RETENTION_DAYS`.

---

## ⏱️ Cron recomendado

```cron
0 3 * * * /root/supabase-backups/bin/run-all.sh
30 3 * * * /root/supabase-backups/bin/rotate-local.sh
```

---

## 🔔 Alertas

Actualmente:
- Telegram

Diseñado para ampliar a email, Slack o webhooks.

---

## 🧠 Principios de diseño

- Una sola fuente de verdad
- Nada automático sin intención
- Backups locales siempre
- Restore manual por seguridad
- Pensado para producción

---

## 📄 Licencia

MIT
