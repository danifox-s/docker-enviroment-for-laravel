# 🐳 Laravel Docker Environment

Минималистичный Docker-шаблон для Laravel-проектов.
**Не содержит Laravel** — только Docker-конфигурация, готовая к переносу в любой проект.

## 📦 Состав

```
.
├── docker/
│   ├── nginx/conf.d/app.conf       # Nginx конфигурация
│   └── php/
│       ├── Dockerfile              # Multi-stage: development + production
│       └── conf.d/
│           ├── php.ini             # Базовые PHP настройки
│           ├── php-production.ini  # Production PHP настройки
│           └── xdebug.ini          # Xdebug конфигурация
├── docker-compose.yml              # Development
├── docker-compose.prod.yml         # Production
├── .dockerignore
├── .env.docker                     # Шаблон Docker-переменных окружения
├── docker-health-check.sh          # Диагностический скрипт
├── install.sh                      # ← Скрипт установки в Laravel-проект
└── Makefile                        # Удобные команды
```

---

## 🚀 Установка в новый Laravel-проект

```bash
# 1. Создайте новый Laravel проект
composer create-project laravel/laravel my-project
cd my-project

# 2. Клонируйте этот репозиторий рядом
git clone https://github.com/your-username/laravel-docker.git ../laravel-docker

# 3. Запустите установщик — скопирует файлы и смержит .env
../laravel-docker/install.sh .

# 4. Задайте уникальное имя проекта в .env
# COMPOSE_PROJECT_NAME=my-project

# 5. Запустите
make dev
```

### Что делает install.sh

- Копирует `docker/`, `docker-compose.yml`, `docker-compose.prod.yml`, `Makefile`, `.dockerignore`, `docker-health-check.sh` в целевой проект
- Умно мержит `.env.docker` в уже существующий `.env` Laravel:
  - **Заменяет** `DB_HOST`, `REDIS_HOST`, `SESSION_DRIVER`, `CACHE_STORE`, `QUEUE_CONNECTION` под Docker
  - **Добавляет** `COMPOSE_PROJECT_NAME`, `APP_PORT`, Xdebug-переменные (только если их нет)
  - Не трогает переменные, которые уже совпадают

```bash
# Посмотреть что будет сделано без применения изменений:
./install.sh /path/to/project --dry-run
```

---

## ✨ Возможности

- 🔀 **Множественные проекты** — уникальные контейнеры, сети и volumes через `COMPOSE_PROJECT_NAME`
- 🐛 **Xdebug** — готов из коробки в development-режиме (порт 9003)
- 📦 **Production ready** — отдельная конфигурация с OpCache JIT, без Xdebug, код в образе
- ⚙️ **Настраиваемые порты** — через переменные окружения

---

## 🔀 Несколько проектов одновременно

Каждый проект должен иметь уникальный `COMPOSE_PROJECT_NAME` и разные порты в `.env`:

| Проект | COMPOSE_PROJECT_NAME | APP_PORT | URL                   |
|--------|---------------------|----------|-----------------------|
| Shop   | `my-shop`           | 8000     | http://localhost:8000 |
| Blog   | `blog`              | 8001     | http://localhost:8001 |
| API    | `api`               | 8002     | http://localhost:8002 |

---

## ⚠️ Важно: команды выполняются внутри контейнеров

Все команды (`php`, `artisan`, `composer`) выполняются **внутри Docker-контейнера**, а не в локальном терминале.

```bash
# Неправильно (локальный терминал)
php artisan migrate
composer require package

# Правильно — через Makefile
make artisan CMD="migrate"
make composer CMD="require package"

# Или войти в контейнер и работать там
make shell
```

> **Для AI-агентов:** перед выполнением любых команд убедитесь, что контейнеры запущены (`make ps`). Используйте `make artisan`, `make composer` или `make shell`. Никогда не запускайте `php`, `artisan` или `composer` напрямую в локальном терминале.
>
> После развёртывания Docker-окружения в новом проекте **обновите `CLAUDE.md`** (или создайте его), добавив эту информацию, чтобы агенты работали корректно в контексте конкретного проекта.

---

## 🔧 Команды Makefile

```bash
make dev             # Полная инициализация (build + up + install)
make up              # Запустить контейнеры (dev)
make down            # Остановить
make restart         # Перезапустить
make ps              # Статус контейнеров
make logs            # Логи всех сервисов
make shell           # Войти в PHP контейнер
make artisan CMD="migrate"           # Artisan команда
make composer CMD="require package"  # Composer команда
make test            # Запустить тесты
make migrate         # Миграции
make migrate-fresh   # Пересоздать БД
make cache-clear     # Очистить кеш
make up-tools        # Запустить с PHPMyAdmin
make health-check    # Проверка состояния
make prod-deploy     # Деплой в production
make check-config    # Проверить конфигурацию и свободность портов
```

---

## 📦 Сервисы

**Development (`docker-compose.yml`):**

| Сервис     | Образ                 | Порт              |
|------------|-----------------------|-------------------|
| app        | PHP 8.4-FPM + Xdebug  | 9003              |
| webserver  | Nginx Alpine          | `APP_PORT`        |
| mysql      | MySQL 8.0             | 3306              |
| redis      | Redis 7 Alpine        | 6379              |
| phpmyadmin | PHPMyAdmin *(profile)*| `PHPMYADMIN_PORT` |
| queue      | PHP-FPM *(profile)*   | —                 |
| scheduler  | PHP-FPM *(profile)*   | —                 |

**Production (`docker-compose.prod.yml`):**
- Xdebug отключён, OpCache JIT включён
- Код упакован в образ (нет volume mount)
- Queue Worker и Scheduler запускаются всегда

---

## ⚙️ Xdebug (PHPStorm)

1. **Settings → PHP → Servers**
   - Host: `localhost`, Port: значение `APP_PORT` из `.env`
   - Debugger: `Xdebug`
   - Path mappings: `/path/to/project` → `/var/www/html`
2. **Settings → PHP → Debug** → Xdebug port: `9003`

---

## 🔄 Development vs Production

| Параметр       | Development            | Production        |
|----------------|------------------------|-------------------|
| Xdebug         | ✅ Включён             | ❌ Отключён       |
| Volume mount   | ✅ Да (live reload)    | ❌ Нет (в образе) |
| OpCache JIT    | ❌                     | ✅                |
| Queue Worker   | Опционально (profile)  | ✅ Всегда         |
| Scheduler      | Опционально (profile)  | ✅ Всегда         |
| Порт по умолч. | 8000                   | 80                |
