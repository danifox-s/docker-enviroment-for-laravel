# 🐳 Docker окружение для Laravel

## 🚀 Быстрый старт

### Development (разработка)
```bash
make dev
```
Откройте: http://localhost:8000

### Production (продакшен)
```bash
make prod-deploy
```
Откройте: http://localhost

---

## 📋 Требования

- Docker >= 20.10
- Docker Compose >= 2.0
- Make (опционально)

---

## 🔧 Основные команды

### Управление контейнерами
```bash
make help            # Показать все команды
make up              # Запустить (development)
make up-prod         # Запустить (production)
make down            # Остановить
make restart         # Перезапустить
make ps              # Статус контейнеров
make logs            # Логи всех сервисов
make health-check    # Проверить здоровье системы
```

### Работа с приложением
```bash
make shell                          # Войти в PHP контейнер
make artisan CMD="migrate"          # Выполнить artisan команду
make composer CMD="require package" # Установить пакет
make test                           # Запустить тесты
make migrate                        # Выполнить миграции
make migrate-fresh                  # Пересоздать БД
make cache-clear                    # Очистить кеш
```

### База данных
```bash
make shell-mysql     # Войти в MySQL
make phpmyadmin-up   # PHPMyAdmin (localhost:8080)
```

---

## 📦 Структура

### Сервисы

**Development:**
- **app** - PHP 8.4-FPM + Xdebug (порт 9003)
- **webserver** - Nginx (порт 8000)
- **mysql** - MySQL 8.0 (порт 3306)
- **redis** - Redis 7 (порт 6379)
- **phpmyadmin** - PHPMyAdmin (порт 8080, опционально)

**Production:**
- Те же + **queue** (Queue Worker) + **scheduler** (Cron Scheduler)
- Xdebug отключен
- Код упакован в образ
- OpCache оптимизирован

### Файлы конфигурации

```
docker/
├── nginx/
│   └── conf.d/
│       └── app.conf              # Nginx конфигурация
└── php/
    ├── Dockerfile                # Multi-stage build
    └── conf.d/
        ├── php.ini               # Базовая конфигурация
        ├── php-production.ini    # Production настройки
        └── xdebug.ini            # Xdebug конфигурация

docker-compose.yml                # Development
docker-compose.prod.yml           # Production
.dockerignore                     # Исключения для Docker
Makefile                          # Команды
```

---

## ⚙️ Настройка

### Первый запуск

```bash
# 1. Копировать .env
cp .env.example .env

# 2. Проверить настройки (должны быть для Docker)
DB_HOST=mysql
REDIS_HOST=redis

# 3. Запустить
make dev

# 4. Открыть
open http://localhost:8000
```

### Настройка Xdebug (PHPStorm)

1. **Settings → PHP → Servers**
   - Name: `docker`
   - Host: `localhost`
   - Port: `8000`
   - Debugger: `Xdebug`
   - ✅ Use path mappings: `/path/to/project` → `/var/www/html`

2. **Settings → PHP → Debug**
   - Xdebug port: `9003`

3. Включить прослушивание и поставить breakpoint

---

## 🔄 Различия между режимами

| Параметр | Development | Production |
|----------|-------------|------------|
| **Команда** | `make dev` | `make prod-deploy` |
| **Порт** | 8000 | 80 |
| **Xdebug** | ✅ Включен | ❌ Отключен |
| **Volume mount** | ✅ Да (live reload) | ❌ Нет (в образе) |
| **OpCache** | Базовый | Агрессивный |
| **PHP Memory** | 512M | 256M |
| **Laravel Cache** | Выключен | ✅ Включен |
| **Queue Worker** | Опционально | ✅ Всегда |
| **Scheduler** | Опционально | ✅ Всегда |

---

## 💡 Практические примеры


### Установка пакета

```bash
make composer CMD="require spatie/laravel-permission"
make artisan CMD="vendor:publish --provider='Spatie\Permission\PermissionServiceProvider'"
make migrate
```

### Работа с БД

```bash
# Создать дамп
docker compose exec mysql mysqldump -ularavel -psecret laravel > backup.sql

# Восстановить
docker compose exec -T mysql mysql -ularavel -psecret laravel < backup.sql

# PHPMyAdmin
make phpmyadmin-up
open http://localhost:8080
# Логин: laravel, Пароль: secret, Server: mysql
```

### Production деплой

```bash
# 1. Подготовить .env
nano .env  # APP_ENV=production, APP_DEBUG=false, сильные пароли

# 2. Тесты
make test

# 3. Деплой
make prod-deploy

# 4. Проверка
make logs
docker compose -f docker-compose.prod.yml ps
```

---

## 🔧 Troubleshooting

### Контейнеры не запускаются

```bash
make logs                # Посмотреть ошибки
make down-all            # Остановить всё
make build               # Пересобрать
make up                  # Запустить снова
```

### Порты заняты

Измените в `docker-compose.yml`:
```yaml
webserver:
  ports:
    - "8080:80"  # Вместо 8000
```

### Проблемы с правами

```bash
make fix-permissions
```

### БД не подключается

```bash
# 1. Проверить что зависимости установлены
make shell
ls vendor  # Должна существовать папка vendor
exit

# Если vendor нет - установить зависимости
make install

# 2. Проверить .env
cat .env | grep DB_HOST  # Должно быть: mysql

# 3. Подождать пока MySQL будет готова
sleep 15
make migrate

# 4. Проверить подключение
make artisan CMD="migrate:status"
```

### Xdebug не работает

```bash
# Проверить
docker compose exec app php -v  # Должен быть Xdebug

# Логи
docker compose exec app cat /var/www/html/storage/logs/xdebug.log

# Перезапустить
make restart
```

### Полная пересборка

```bash
make down-all   # Удалит контейнеры и volumes
make clean      # Очистит Docker систему
make build      # Пересоберёт образы
make up         # Запустит
```

---

## 🎯 Полезная информация

### Проверка здоровья

```bash
make health-check  # Автоматическая диагностика
```

### Без Makefile

```bash
# Development
docker compose up -d
docker compose exec app composer install
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate

# Production
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d
```

### Volumes (данные)

- `mysql_data` - база данных MySQL
- `redis_data` - данные Redis
- `./:/var/www/html` - код приложения (только dev)

⚠️ `make down-all` удалит ВСЕ данные включая БД!

### Переменные окружения

**Для Docker используйте:**
```env
DB_HOST=mysql          # не 127.0.0.1
REDIS_HOST=redis       # не 127.0.0.1
SESSION_DRIVER=redis
CACHE_STORE=redis
QUEUE_CONNECTION=redis
```

**Xdebug настройки (в .env):**
```env
XDEBUG_MODE=develop,debug,coverage
XDEBUG_CLIENT_HOST=host.docker.internal
XDEBUG_CLIENT_PORT=9003
```

---

## 🛠️ Makefile команды (полный список)

```bash
# Docker
make up              # Запустить (dev)
make up-prod         # Запустить (production)
make up-full         # Запустить всё (worker+scheduler)
make down            # Остановить
make down-prod       # Остановить production
make down-all        # Остановить и удалить volumes
make build           # Пересобрать
make build-prod      # Пересобрать для production
make restart         # Перезапустить
make ps              # Статус
make logs            # Логи всех
make logs-app        # Логи PHP
make logs-webserver  # Логи Nginx
make logs-mysql      # Логи MySQL

# Shell
make shell           # Войти в PHP контейнер
make shell-root      # Войти как root
make shell-mysql     # Войти в MySQL

# Laravel
make install         # Установить зависимости
make composer CMD="..." # Composer команда
make artisan CMD="..." # Artisan команда
make test            # Тесты
make test-coverage   # Тесты с покрытием
make migrate         # Миграции
make migrate-fresh   # Пересоздать БД
make seed            # Сидеры
make key-generate    # Сгенерировать APP_KEY
make cache-clear     # Очистить кеш
make cache-optimize  # Оптимизировать кеш (prod)
make queue-work      # Запустить worker

# Инструменты
make phpmyadmin-up   # PHPMyAdmin
make health-check    # Проверка здоровья
make fix-permissions # Исправить права
make clean           # Очистить Docker

# Быстрые команды
make dev             # Быстрый старт (build+up+install)
make prod-deploy     # Production деплой
```

---

## ⚠️ Важно

### Безопасность
- ⚠️ В production смените ВСЕ пароли в .env
- ⚠️ Никогда не коммитьте .env файлы
- ⚠️ Используйте HTTPS в production

### Данные
- 💾 БД сохраняется в Docker volumes
- ⚠️ `make down-all` удалит ВСЕ данные
- ✅ `make down` сохранит данные

### Production
- ✅ Настройте регулярные бэкапы
- ✅ Используйте сильные пароли
- ✅ Настройте мониторинг
- ✅ Настройте SSL/HTTPS
