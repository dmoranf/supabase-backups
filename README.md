# Supabase Backups (DB + Storage S3) — Guía completa

Este repositorio implementa un sistema **auto‑contenible** para hacer copias de seguridad de proyectos **Supabase** en un VPS Linux:

- ✅ **Backup de Base de Datos** (PostgreSQL) con `pg_dump`
- ✅ **Backup de Storage** usando **S3 compatible** (Supabase Storage S3) con `rclone`
- ✅ **Cifrado** de artefactos con `age`
- ✅ **Retención / limpieza** local (y opcionalmente remota)
- ✅ **Multi‑proyecto** (varios Supabase en la misma instalación)
- ✅ **Orquestación** con `bin/run-all.sh` (ideal para cron)
- ✅ **Alertas** (Telegram opcional)

> Importante: si usas `bin/run-all.sh`, **NO necesitas exportar variables manualmente antes**.  
> `run-all` carga `config/global.env` y recorre automáticamente `config/projects/*.env` usando `bin/_bootstrap.sh`.

---

## 1) Requisitos

### Paquetes necesarios (Debian/Ubuntu)

```bash
apt update
apt install -y postgresql-client rclone age jq tar
```

Verificación rápida:

```bash
psql --version
rclone version
age --version
jq --version
tar --version
```

---

## 2) Estructura y ficheros (los que tienes en `bin/`)

Listado actual:

```text
bin/
├── _bootstrap.sh
├── run-all.sh
├── backup-db.sh
├── restore-db.sh
├── backup-storage.sh
├── rotate-backup.sh
├── rotate-local.sh
└── alert.sh
```

### ¿Qué hace cada uno?

#### `bin/_bootstrap.sh`
- Punto común de “arranque”.
- Carga `config/global.env`.
- Carga el fichero de proyecto (`config/projects/*.env`) que corresponda.
- Deja preparadas rutas (`BASE_DIR`, `LOG_DIR`, etc.) y variables necesarias.

> Si un script “no encuentra variables”, normalmente es porque no se ha ejecutado pasando por `_bootstrap.sh`.

#### `bin/run-all.sh`
- Orquestador recomendado para cron.
- Recorre todos los proyectos (`config/projects/*.env`) y ejecuta las acciones definidas (DB, Storage y/o rotación).
- Integra logs y (opcionalmente) alertas.

**Ventaja:** para cron, **un único punto de entrada**.

#### `bin/backup-db.sh`
- Genera un dump de PostgreSQL con `pg_dump`.
- Comprime/cifra (según vuestra implementación).
- Guarda la copia en el directorio local del proyecto.

#### `bin/restore-db.sh`
- Restaura un dump (descifra/descomprime si aplica) contra PostgreSQL.

#### `bin/backup-storage.sh`
- Realiza un `rclone sync` desde Supabase Storage S3 (endpoint S3 compatible).
- Empaqueta el resultado (tar) + cifra con `age`.
- Guarda copia local en el directorio del proyecto.
- (Opcional) sube a remoto si está configurado.

#### `bin/rotate-backup.sh`
- Limpieza principal por retención: borra backups antiguos (local y/o remoto según vuestra lógica).
- Se basa en `LOCAL_RETENTION_DAYS` (global) y/o en rutas del proyecto.

#### `bin/rotate-local.sh`
- Limpieza local auxiliar (si lo usáis para tmp/cache/logs o subcarpetas específicas).
- Normalmente se ejecuta después de backups o desde `rotate-backup.sh`.

#### `bin/alert.sh`
- Envío de alertas (p.ej. Telegram) si `ALERT_TELEGRAM_ENABLED=true`.
- Lo suele invocar `run-all.sh` o scripts concretos ante fallos/éxitos.

---

## 3) Configuración global (infraestructura)

### `config/global.env` (tal como lo estáis usando)

> Aquí NO se define nada específico de Storage S3. Solo infraestructura común.

```bash
#!/usr/bin/env bash

# Base
export BASE_DIR="/opt/supabase-backups"
export BIN_DIR="${BASE_DIR}/bin"
export LOG_DIR="${BASE_DIR}/logs"
export TMP_DIR="${BASE_DIR}/tmp"

# PostgreSQL
export PG_DUMP_BIN="/usr/lib/postgresql/15/bin/pg_dump"

# Backups locales (retención en días)
export LOCAL_RETENTION_DAYS=7

# Cifrado
export AGE_PUBLIC_KEY_FILE="${BASE_DIR}/config/backup.pub"

# Alertas (opcional)
export ALERT_TELEGRAM_ENABLED=false
export ALERT_TELEGRAM_BOT_TOKEN="XXXXX"
export ALERT_TELEGRAM_CHAT_ID="YYYYY"

# Remoto (opcional)
export RCLONE_REMOTE=""
```

---

## 4) Configuración por proyecto (Supabase + Storage S3)

Cada proyecto tiene un fichero en `config/projects/`.

Ejemplo recomendado: `config/projects/demo.env`

```bash
#!/usr/bin/env bash

export PROJECT_NAME="Demo"
export ENVIRONMENT="production"

# Supabase DB
export PGHOST="db.xxxxx.supabase.co"
export PGPORT="5432"
export PGDATABASE="postgres"
export PGUSER="postgres"
export PGPASSWORD="SUPER_SECRET"

# Paths derivados
export PROJECT_DIR="${BASE_DIR}/backups/${PROJECT_NAME}"
export LOG_FILE="${LOG_DIR}/${PROJECT_NAME}.log"
export LOCAL_BACKUP_DIR="${BASE_DIR}/backups/${PROJECT_NAME}"

# Remoto (opcional por proyecto)
export RCLONE_BASE_PATH="${PROJECT_NAME}/${ENVIRONMENT}"

# Supabase Storage (S3)
export SUPABASE_URL="https://xxxx.supabase.co"

# OJO: la variable correcta es AWS_ACCESS_KEY_ID (con doble "C")
export AWS_ACCESS_KEY_ID="SUPABASE_S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="SUPABASE_S3_SECRET_KEY"

# Endpoint S3 compatible de Supabase (por proyecto)
export RCLONE_S3_ENDPOINT="https://xxxx.supabase.co/storage/v1/s3"
```

### Notas importantes
- `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY` **son las variables estándar** que rclone lee cuando `env_auth=true`.
- El endpoint S3 compatible de Supabase es:
  - ✅ `https://<project-ref>.supabase.co/storage/v1/s3`
  - ❌ NO uses `...storage.supabase.co...` si te da problemas (el endpoint recomendado es el anterior).
- Puedes tener **un endpoint distinto por proyecto** (por eso va aquí y no en global).

---

## 5) Cifrado con age

### 5.1 Generar clave privada y pública

```bash
age-keygen -o backup.key
```

- `backup.key` = **clave privada** (NO la subas al repo)
- `backup.pub` = **clave pública** (sí puede estar en el repo)

Crear/actualizar `config/backup.pub`:

```bash
grep public backup.key > config/backup.pub
chmod 600 backup.key config/backup.pub
```

---

## 6) Supabase Storage S3: crear keys en el Dashboard

Para cada proyecto:

1. Supabase Dashboard
2. **Storage**
3. **S3**
4. Crear **Access Key** y **Secret**
5. Copiarlo al `config/projects/<proyecto>.env`:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

> Estas keys son específicas de Storage S3. No son la service role key.

---

## 7) rclone: configuración mínima (sin secretos en disco)

### 7.1 ¿Dónde está el config?

```bash
rclone config file
```

Habitual (root):

```text
/root/.config/rclone/rclone.conf
```

### 7.2 `rclone.conf` mínimo recomendado

```ini
[supabase-s3]
type = s3
provider = Other
env_auth = true
region = us-east-1
acl = private
```

**No metas** credenciales ni endpoint aquí: se inyectan desde el `project.env` por variables de entorno.

### 7.3 Verificación rápida (con un proyecto cargado)

Para que rclone vea `AWS_*` y `RCLONE_S3_ENDPOINT`, primero debes cargar un proyecto (o usar `run-all`).

Prueba manual (sin cron):

```bash
# Carga global + un proyecto (elige uno)
source config/global.env
source config/projects/demo.env

# Verifica que rclone ve endpoint y creds por entorno
env | egrep 'AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|RCLONE_S3_ENDPOINT'

# Listado (si vuestro backup-storage usa --s3-endpoint internamente, esto es opcional)
rclone lsd supabase-s3:
```

> Si vuestro `backup-storage.sh` pasa el endpoint como flag (`--s3-endpoint "$RCLONE_S3_ENDPOINT"`), `rclone lsd` funcionará sin tocar el config.

---

## 8) Ejecución manual (para pruebas)

### 8.1 Ejecutar un proyecto concreto (manual)

Si quieres probar solo un proyecto sin `run-all`:

```bash
export SUPABASE_BACKUP_ENV="config/projects/demo.env"
bin/backup-db.sh
bin/backup-storage.sh
```

> Útil para depurar credenciales o conectividad de un proyecto.

### 8.2 Ejecutar TODOS los proyectos (manual)

```bash
bin/run-all.sh
```

---

## 9) Cron: ejemplos recomendados (DB diario + Storage semanal + limpieza)

> Cron **debe llamar a `run-all.sh`** (no hace falta exportar nada antes).

Edita crontab:

```bash
crontab -e
```

### 9.1 Backup DB diario nocturno (todos los proyectos)
Ejemplo: todos los días a las **02:00**

```cron
0 2 * * * cd /opt/supabase-backups && bin/run-all.sh >> logs/cron-run-all.log 2>&1
```

> Si vuestro `run-all.sh` ejecuta DB por defecto cada día, este es el setup más simple.

### 9.2 Backup Storage semanal (proyecto a proyecto)
Ejemplo: domingos a las **03:30**

```cron
30 3 * * 0 cd /opt/supabase-backups && bin/run-all.sh >> logs/cron-run-all-storage.log 2>&1
```

> **Recomendación**: si queréis que el storage sea “semanal” de verdad, haced que `run-all.sh` decida:
> - DB: diario
> - Storage: solo si es domingo (o si recibe un flag)

Si vuestro `run-all.sh` soporta flags (si no, podéis añadirlo), el patrón ideal sería:
- DB diario: `bin/run-all.sh --db`
- Storage semanal: `bin/run-all.sh --storage`

(usa los flags reales que tengáis implementados).

### 9.3 Limpieza diaria (retención)
Ejemplo: todos los días a las **04:30**

```cron
30 4 * * * cd /opt/supabase-backups && bin/rotate-backup.sh >> logs/cron-rotate.log 2>&1
```

---

## 10) Retención / limpieza: cómo funciona (conceptual)

- `LOCAL_RETENTION_DAYS` (global) define cuántos días conservar backups locales.
- `rotate-backup.sh` elimina:
  - backups locales antiguos (por edad)
  - (opcional) backups remotos si `RCLONE_REMOTE` y `RCLONE_BASE_PATH` se usan
- `rotate-local.sh` puede limpiar `tmp/` y restos intermedios.

> Consejo: mantén logs de cron (`logs/cron-*.log`) y rota con logrotate si crecen.

---

## 11) Restore (manual)

### 11.1 Restore DB (ejemplo conceptual)
Depende de vuestro formato exacto (si está `.gz.age`, etc.). Un patrón típico:

```bash
age -d -i backup.key demo_db_YYYY-MM-DD.sql.gz.age | gunzip | psql \
  "host=$PGHOST port=$PGPORT dbname=$PGDATABASE user=$PGUSER password=$PGPASSWORD sslmode=require"
```

### 11.2 Restore Storage (S3)
Si el backup de storage genera un tar cifrado que contiene una carpeta `data/`:

```bash
age -d -i backup.key Demo_storage_YYYY-MM-DD_HHMMSS.tar.gz.age | tar -xz
rclone sync data/ supabase-s3:
```

> En restore, ten cuidado: `rclone sync` puede borrar en destino si faltan ficheros en origen.  
> Para pruebas: usa `rclone copy` primero.

---

## 12) Seguridad y buenas prácticas

- No subas al repo:
  - `backup.key`
  - `config/projects/*.env` reales con secretos (o al menos exclúyelos en `.gitignore`)
- Ejecuta cron siempre con el **mismo usuario** que tiene:
  - `rclone.conf`
  - permisos de escritura en `/opt/supabase-backups`
- Añade un **lock** en `run-all.sh` (recomendado) para evitar solapes si una tarea se alarga.
- Prueba restores periódicamente.

---

## 13) Quick Start (copiar/pegar)

1) Instalar dependencias:
```bash
apt install -y postgresql-client rclone age jq tar
```

2) Crear claves `age`:
```bash
cd /opt/supabase-backups
age-keygen -o backup.key
grep public backup.key > config/backup.pub
chmod 600 backup.key config/backup.pub
```

3) Crear proyecto:
```bash
cp config/projects/demo.env config/projects/mi-proyecto.env
# Edita credenciales DB y claves S3 en mi-proyecto.env
```

4) Configurar rclone:
```bash
rclone config file
# Asegúrate de tener un remote [supabase-s3] como en la sección 7.2
```

5) Probar manual:
```bash
bin/run-all.sh
```

6) Programar cron:
```bash
crontab -e
# pega las entradas de la sección 9
```

---

## 14) Resumen

- `run-all.sh` es el punto de entrada recomendado (cron)
- Storage se respalda vía **S3 oficial** (rclone)
- Configuración de Storage **por proyecto**
- Cifrado con `age`
- Limpieza con `rotate-backup.sh`

Listo para producción, con un diseño claro y mantenible.
