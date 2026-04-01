# 🐳 Laravel Docker Environment

A minimal Docker template for Laravel projects.
**Does not include Laravel** — only Docker configuration, ready to be copied into any project.

## 📦 Structure

```
.
├── docker/
│   ├── nginx/conf.d/app.conf       # Nginx configuration
│   └── php/
│       ├── Dockerfile              # Multi-stage: development + production
│       └── conf.d/
│           ├── php.ini             # Base PHP settings
│           ├── php-production.ini  # Production PHP settings
│           └── xdebug.ini          # Xdebug configuration
├── docker-compose.yml              # Development
├── docker-compose.prod.yml         # Production
├── .dockerignore
├── .env.docker                     # Docker environment variables template
├── docker-health-check.sh          # Diagnostic script
├── install.sh                      # ← Installer script for Laravel projects
└── Makefile                        # Convenience commands
```

---

## 🚀 Installing into a new Laravel project

```bash
# 1. Create a new Laravel project
composer create-project laravel/laravel my-project
cd my-project

# 2. Run the installer — copies files and merges .env
laravel-docker .

# 3. Set a unique project name in .env
# COMPOSE_PROJECT_NAME=my-project

# 4. Start
make dev
```

### What install.sh does

- Copies `docker/`, `docker-compose.yml`, `docker-compose.prod.yml`, `Makefile`, `.dockerignore`, `docker-health-check.sh`, `README.md` (as `DOCKER.md`) into the target project
- Smartly merges `.env.docker` into the existing Laravel `.env`:
  - **Replaces** `DB_HOST`, `REDIS_HOST`, `SESSION_DRIVER`, `CACHE_STORE`, `QUEUE_CONNECTION` for Docker
  - **Adds** `COMPOSE_PROJECT_NAME`, `APP_PORT`, `DB_PORT_EXTERNAL`, Xdebug and PHP variables (only if missing)
  - Leaves variables that already match untouched

```bash
# Preview changes without applying them:
./install.sh /path/to/project --dry-run
```

---

## ✨ Features

- 🔀 **Multiple projects** — unique containers, networks and volumes via `COMPOSE_PROJECT_NAME`
- 🐛 **Xdebug** — ready out of the box in development mode (port 9003)
- 📦 **Production ready** — separate configuration with OpCache JIT, no Xdebug, code baked into image
- ⚙️ **Configurable ports** — via environment variables

---

## 🔀 Running multiple projects simultaneously

Each project must have a unique `COMPOSE_PROJECT_NAME` and different ports in `.env`:

| Project | COMPOSE_PROJECT_NAME | APP_PORT | URL                   |
|---------|---------------------|----------|-----------------------|
| Shop    | `my-shop`           | 8000     | http://localhost:8000 |
| Blog    | `blog`              | 8001     | http://localhost:8001 |
| API     | `api`               | 8002     | http://localhost:8002 |

---

## ⚠️ Important: commands run inside containers

All commands (`php`, `artisan`, `composer`) must be run **inside the Docker container**, not in your local terminal.

```bash
# Wrong (local terminal)
php artisan migrate
composer require package

# Correct — via Makefile
make artisan CMD="migrate"
make composer CMD="require package"

# Or enter the container and work there
make shell
```

> **For AI agents:** before running any commands, make sure the containers are running (`make ps`). Use `make artisan`, `make composer` or `make shell`. Never run `php`, `artisan` or `composer` directly in the local terminal.
>
> After deploying the Docker environment in a new project, **update `CLAUDE.md`** (or create it) with this information so agents work correctly in the project context.

---

## 🔧 Makefile commands

```bash
make dev             # Full initialization (build + up + install)
make up              # Start containers (dev)
make down            # Stop containers
make restart         # Restart containers
make ps              # Container status
make logs            # Logs for all services
make shell           # Enter the PHP container
make artisan CMD="migrate"           # Artisan command
make composer CMD="require package"  # Composer command
make test            # Run tests
make migrate         # Run migrations
make migrate-fresh   # Recreate DB
make cache-clear     # Clear cache
make up-tools        # Start with PHPMyAdmin
make health-check    # System health check
make prod-deploy     # Deploy to production
make check-config    # Check configuration and port availability
```

---

## 📦 Services

**Development (`docker-compose.yml`):**

| Service    | Image                 | Port              |
|------------|-----------------------|-------------------|
| app        | PHP 8.4-FPM + Xdebug  | 9003              |
| webserver  | Nginx Alpine          | `APP_PORT`        |
| mysql      | MySQL 8.0             | `DB_PORT_EXTERNAL`|
| redis      | Redis 7 Alpine        | 6379              |
| phpmyadmin | PHPMyAdmin *(profile)*| `PHPMYADMIN_PORT` |
| queue      | PHP-FPM *(profile)*   | —                 |
| scheduler  | PHP-FPM *(profile)*   | —                 |

**Production (`docker-compose.prod.yml`):**
- Xdebug disabled, OpCache JIT enabled
- Code baked into image (no volume mount)
- Queue Worker and Scheduler always run

---

## ⚙️ Xdebug (PHPStorm)

1. **Settings → PHP → Servers**
   - Host: `localhost`, Port: value of `APP_PORT` from `.env`
   - Debugger: `Xdebug`
   - Path mappings: `/path/to/project` → `/var/www/html`
2. **Settings → PHP → Debug** → Xdebug port: `9003`

---

## 🔄 Development vs Production

| Parameter    | Development            | Production        |
|--------------|------------------------|-------------------|
| Xdebug       | ✅ Enabled             | ❌ Disabled       |
| Volume mount | ✅ Yes (live reload)   | ❌ No (in image)  |
| OpCache JIT  | ❌                     | ✅                |
| Queue Worker | Optional (profile)     | ✅ Always         |
| Scheduler    | Optional (profile)     | ✅ Always         |
| Default port | 8000                   | 80                |
