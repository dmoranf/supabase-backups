# Supabase Backups (Database + Storage S3)

Este repositorio proporciona un **sistema sencillo, robusto y cifrado** para realizar copias de seguridad de proyectos **Supabase**, cubriendo:

- ✅ Base de datos PostgreSQL (pg_dump)
- ✅ Storage usando **Supabase S3 compatible + rclone**
- ✅ Cifrado con `age`
- ✅ Copias locales
- ✅ Preparado para múltiples proyectos

> **Nota**: A partir de ahora, el backup de Storage **NO usa la API REST**, sino el endpoint **S3 compatible oficial de Supabase**, que es más estable y mantenible.

---

## 1. Requisitos

Sistema Linux (Debian/Ubuntu recomendado).

### Paquetes necesarios

```bash
apt install -y   postgresql-client   rclone   age   jq   tar
```

---

## 2. Estructura del proyecto

```text
supabase-backups/
├── bin/
│   ├── backup-db.sh
│   └── backup-storage.sh
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

## 3. Configuración global

### `config/global.env`

Variables comunes a todos los proyectos e infraestructura:

```bash
#!/usr/bin/env bash

BASE_DIR="/root/supabase-backups"
BIN_DIR="${BASE_DIR}/bin"
TMP_DIR="${BASE_DIR}/tmp"
LOG_DIR="${BASE_DIR}/logs"

AGE_PUBLIC_KEY_FILE="${BASE_DIR}/config/backup.pub"

# Retención local (en días)
LOCAL_RETENTION_DAYS=7

# rclone
export RCLONE_CONFIG="/root/.config/rclone/rclone.conf"

# Endpoint S3 de Supabase (se puede cambiar sin tocar rclone.conf)
export RCLONE_S3_ENDPOINT="https://PROJECT_REF.supabase.co/storage/v1/s3"

# Alertas (opcional)
ALERT_TELEGRAM_ENABLED=false
ALERT_TELEGRAM_BOT_TOKEN=""
ALERT_TELEGRAM_CHAT_ID=""
```

---

## 4. Configuración del proyecto

Cada proyecto Supabase tiene **su propio fichero**, muy simple.

### `config/projects/demo.env`

```bash
#!/usr/bin/env bash

PROJECT_NAME="demo"
ENVIRONMENT="production"

# Base de datos Supabase
PGHOST="db.xxxxx.supabase.co"
PGPORT="5432"
PGDATABASE="postgres"
PGUSER="postgres"
PGPASSWORD="SUPER_SECRET_PASSWORD"

# Backups locales de este proyecto
LOCAL_BACKUP_DIR="/root/supabase-backups/backups/demo"
```

Para añadir un nuevo proyecto:

```bash
cp config/projects/demo.env config/projects/otro.env
```

---

## 5. Claves de cifrado (age)

### Generar claves

```bash
age-keygen -o backup.key
```

- Guarda **`backup.key`** en un lugar seguro (NO en el repo).
- Copia la clave pública a:

```bash
cat backup.key | grep public > config/backup.pub
chmod 600 backup.key config/backup.pub
```

---

## 6. Configuración de Supabase Storage S3

Supabase expone un endpoint **S3 compatible**.

### Paso obligatorio en el dashboard

1. Supabase Dashboard
2. **Storage**
3. **S3**
4. Crear un **Access Key + Secret**

Guarda esos valores.

---

## 7. Configuración de rclone

### Variables de entorno (OBLIGATORIO)

rclone usa las variables estándar de AWS:

```bash
export AWS_ACCESS_KEY_ID="TU_SUPABASE_S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="TU_SUPABASE_S3_SECRET_KEY"
```

Pueden ir en:
- `.bashrc`
- `.profile`
- `cron`
- systemd
- o exportarse antes de ejecutar scripts

---

### `rclone.conf` mínimo recomendado

Ubicación habitual:

```text
/root/.config/rclone/rclone.conf
```

Contenido:

```ini
[supabase-s3]
type = s3
provider = Other
env_auth = true
region = us-east-1
acl = private
```

> ⚠️ **No pongas credenciales ni endpoint en el config**  
> Se pasan por variables de entorno.

---

### Verificación

```bash
rclone lsd supabase-s3:
```

Debe listar los buckets del proyecto (incluidos UUID).

---

## 8. Backup del Storage (S3)

### Ejecutar manualmente

```bash
export SUPABASE_BACKUP_ENV=config/projects/demo.env
bin/backup-storage.sh
```

El proceso realiza:

1. `rclone sync` completo desde Supabase S3
2. Compresión (`tar.gz`)
3. Cifrado (`.age`)
4. Copia local en `backups/<proyecto>/storage/`

---

## 9. Backup de la base de datos

```bash
export SUPABASE_BACKUP_ENV=config/projects/demo.env
bin/backup-db.sh
```

---

## 10. Restore del Storage (manual)

```bash
age -d -i backup.key demo_storage_YYYY-MM-DD_HHMMSS.tar.gz.age | tar -xz
rclone sync data/ supabase-s3:
```

---

## 11. Buenas prácticas

- Ejecutar siempre los scripts con el **mismo usuario** que configuró rclone
- No versionar:
  - claves
  - backups
  - logs
- Usar cron o systemd timers
- Probar restores periódicamente

---

## 12. Resumen

- ✅ Storage respaldado vía **S3 oficial**
- ✅ Sin API REST frágil
- ✅ rclone probado y robusto
- ✅ Configuración mínima por proyecto
- ✅ Cifrado fuerte
- ✅ Restore sencillo

Este enfoque es el **más fiable y mantenible** hoy en Supabase.
