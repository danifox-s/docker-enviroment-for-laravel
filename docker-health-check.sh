#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}  Docker Health Check${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

# Проверка Docker
echo -e "${YELLOW}Проверка Docker...${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✓${NC} Docker установлен: $DOCKER_VERSION"
else
    echo -e "${RED}✗${NC} Docker не установлен"
    exit 1
fi

# Проверка Docker Compose
echo -e "${YELLOW}Проверка Docker Compose...${NC}"
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    echo -e "${GREEN}✓${NC} Docker Compose установлен: $COMPOSE_VERSION"
else
    echo -e "${RED}✗${NC} Docker Compose не установлен"
    exit 1
fi

# Проверка запущенных контейнеров
echo ""
echo -e "${YELLOW}Проверка контейнеров...${NC}"
CONTAINERS=$(docker compose ps --format json 2>/dev/null | jq -r '.Name' 2>/dev/null)

if [ -z "$CONTAINERS" ]; then
    echo -e "${YELLOW}⚠${NC} Контейнеры не запущены"
    echo -e "${BLUE}Запустите: make up${NC}"
else
    while IFS= read -r container; do
        STATE=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)

        if [ "$STATE" == "running" ]; then
            if [ "$HEALTH" == "healthy" ] || [ "$HEALTH" == "<no value>" ]; then
                echo -e "${GREEN}✓${NC} $container: running"
            elif [ "$HEALTH" == "unhealthy" ]; then
                echo -e "${RED}✗${NC} $container: running but unhealthy"
            else
                echo -e "${YELLOW}⚠${NC} $container: running (health: $HEALTH)"
            fi
        else
            echo -e "${RED}✗${NC} $container: $STATE"
        fi
    done <<< "$CONTAINERS"
fi

# Проверка портов
echo ""
echo -e "${YELLOW}Проверка портов...${NC}"

check_port() {
    local port=$1
    local service=$2
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Порт $port ($service) доступен"
    else
        echo -e "${RED}✗${NC} Порт $port ($service) не доступен"
    fi
}

check_port 8000 "Nginx/Приложение"
check_port 3306 "MySQL (если проброшен)"
check_port 8080 "PHPMyAdmin (если запущен)"

# Проверка volumes
echo ""
echo -e "${YELLOW}Проверка volumes...${NC}"
VOLUMES=$(docker volume ls --filter name=laravel-1loc --format "{{.Name}}" 2>/dev/null)
if [ -z "$VOLUMES" ]; then
    echo -e "${YELLOW}⚠${NC} Volumes не найдены"
else
    while IFS= read -r volume; do
        echo -e "${GREEN}✓${NC} $volume"
    done <<< "$VOLUMES"
fi

# Проверка .env файла
echo ""
echo -e "${YELLOW}Проверка конфигурации...${NC}"
if [ -f ".env" ]; then
    echo -e "${GREEN}✓${NC} .env файл существует"

    # Проверка критичных переменных
    if grep -q "APP_KEY=base64:" .env; then
        echo -e "${GREEN}✓${NC} APP_KEY установлен"
    else
        echo -e "${RED}✗${NC} APP_KEY не установлен (запустите: docker compose exec app php artisan key:generate)"
    fi

    if grep -q "DB_HOST=mysql" .env; then
        echo -e "${GREEN}✓${NC} DB_HOST настроен для Docker"
    else
        echo -e "${YELLOW}⚠${NC} DB_HOST может быть не настроен для Docker"
    fi

    if grep -q "REDIS_HOST=redis" .env; then
        echo -e "${GREEN}✓${NC} REDIS_HOST настроен для Docker"
    else
        echo -e "${YELLOW}⚠${NC} REDIS_HOST может быть не настроен для Docker"
    fi
else
    echo -e "${RED}✗${NC} .env файл не найден (скопируйте из .env.example)"
fi

# Проверка логов на ошибки
echo ""
echo -e "${YELLOW}Проверка логов на критичные ошибки...${NC}"
if [ -f "storage/logs/laravel.log" ]; then
    ERROR_COUNT=$(grep -c "ERROR" storage/logs/laravel.log 2>/dev/null || echo "0")
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}⚠${NC} Найдено ошибок в логах: $ERROR_COUNT"
        echo -e "${BLUE}Проверьте: storage/logs/laravel.log${NC}"
    else
        echo -e "${GREEN}✓${NC} Критичных ошибок в логах не найдено"
    fi
else
    echo -e "${YELLOW}⚠${NC} Файл логов не найден"
fi

# Проверка подключения к БД
echo ""
echo -e "${YELLOW}Проверка подключения к БД...${NC}"
if docker compose ps | grep -q "laravel_app.*Up"; then
    DB_CHECK=$(docker compose exec -T app php artisan migrate:status 2>&1)
    if echo "$DB_CHECK" | grep -q "Migration name"; then
        echo -e "${GREEN}✓${NC} Подключение к БД работает"
    else
        echo -e "${RED}✗${NC} Не удалось подключиться к БД"
        echo -e "${BLUE}Проверьте: make logs-mysql${NC}"
    fi
else
    echo -e "${YELLOW}⚠${NC} Контейнер app не запущен"
fi

# Итоговый статус
echo ""
echo -e "${BLUE}==================================${NC}"
echo -e "${GREEN}Проверка завершена!${NC}"
echo ""
echo -e "${BLUE}Полезные команды:${NC}"
echo -e "  make help       - Показать все команды"
echo -e "  make logs       - Просмотр логов"
echo -e "  make ps         - Статус контейнеров"
echo -e "  make shell      - Войти в контейнер"
echo -e "${BLUE}==================================${NC}"

