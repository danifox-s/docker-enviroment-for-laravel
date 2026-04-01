#!/bin/bash

# ==============================================
# Laravel Docker Environment Installer
# ==============================================
# Копирует Docker-файлы в ваш Laravel-проект и мержит .env.docker в .env
#
# Использование:
#   ./install.sh                    # установить в текущую директорию
#   ./install.sh /path/to/project   # установить в указанную директорию
#   ./install.sh . --dry-run        # показать, что будет сделано, без изменений

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Директория этого скрипта (источник Docker-файлов)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Целевая директория
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# Режим dry-run
DRY_RUN=false
if [[ "$1" == "--dry-run" ]] || [[ "$2" == "--dry-run" ]]; then
    DRY_RUN=true
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Laravel Docker Environment Installer${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${CYAN}Источник:${NC} $SCRIPT_DIR"
echo -e "${CYAN}Цель:${NC}    $TARGET_DIR"
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}  [DRY RUN — изменения не применяются]${NC}"
fi
echo ""

# --- Проверки ---

if [ "$SCRIPT_DIR" = "$TARGET_DIR" ]; then
    echo -e "${RED}✗ Нельзя устанавливать в саму себя. Укажите путь к Laravel-проекту.${NC}"
    echo "  Пример: ./install.sh ~/projects/my-laravel-app"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}✗ Директория не найдена: $TARGET_DIR${NC}"
    exit 1
fi

# --- Предупреждение и подтверждение ---

if [ "$DRY_RUN" = false ]; then
    echo -e "${YELLOW}Что будет сделано:${NC}"
    echo -e "  • Скопированы файлы: ${CYAN}docker/, docker-compose.yml, docker-compose.prod.yml, Makefile, .dockerignore, .env.docker${NC}"
    echo -e "  • В ${CYAN}.env${NC} будут заменены: DB_HOST, DB_PORT, DB_DATABASE, DB_USERNAME, DB_PASSWORD,"
    echo -e "    REDIS_HOST, REDIS_CLIENT, SESSION_DRIVER, CACHE_STORE, QUEUE_CONNECTION"
    echo -e "  • В ${CYAN}.env${NC} будут добавлены: COMPOSE_PROJECT_NAME, APP_PORT, DB_PORT_EXTERNAL, Xdebug и PHP переменные"
    echo ""
    echo -e "${YELLOW}Существующие файлы будут перезаписаны без возможности отмены.${NC}"
    echo ""
    echo -e "Установить Docker-окружение в ${CYAN}$TARGET_DIR${NC}?"
    echo -e "Введите ${GREEN}yes${NC} для подтверждения: "
    read -r CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${RED}Установка отменена.${NC}"
        exit 0
    fi
    echo ""
fi

# --- Функции ---

copy_item() {
    local src="$1"
    local dst="$2"
    if [ -e "$dst" ]; then
        echo -e "${YELLOW}  ~ Уже существует (перезаписываю): $(basename "$dst")${NC}"
    else
        echo -e "${GREEN}  + Копирую: $(basename "$dst")${NC}"
    fi
    if [ "$DRY_RUN" = false ]; then
        if [ -d "$src" ]; then
            cp -r "$src" "$dst"
        else
            cp "$src" "$dst"
        fi
    fi
}

# --- 1. Копирование Docker-файлов ---

echo -e "${BLUE}[1/3] Копирование Docker-файлов...${NC}"

copy_item "$SCRIPT_DIR/docker"                   "$TARGET_DIR/docker"
copy_item "$SCRIPT_DIR/docker-compose.yml"       "$TARGET_DIR/docker-compose.yml"
copy_item "$SCRIPT_DIR/docker-compose.prod.yml"  "$TARGET_DIR/docker-compose.prod.yml"
copy_item "$SCRIPT_DIR/.dockerignore"            "$TARGET_DIR/.dockerignore"
copy_item "$SCRIPT_DIR/Makefile"                 "$TARGET_DIR/Makefile"
copy_item "$SCRIPT_DIR/docker-health-check.sh"   "$TARGET_DIR/docker-health-check.sh"
copy_item "$SCRIPT_DIR/.env.docker"              "$TARGET_DIR/.env.docker"

if [ "$DRY_RUN" = false ]; then
    chmod +x "$TARGET_DIR/docker-health-check.sh"
fi

echo ""

# --- 2. Merge .env.docker → .env ---

echo -e "${BLUE}[2/3] Обработка переменных окружения...${NC}"

DOCKER_ENV_FILE="$SCRIPT_DIR/.env.docker"
TARGET_ENV="$TARGET_DIR/.env"
TARGET_ENV_EXAMPLE="$TARGET_DIR/.env.example"

# Если .env не существует — создаём из .env.example
if [ ! -f "$TARGET_ENV" ]; then
    if [ -f "$TARGET_ENV_EXAMPLE" ]; then
        echo -e "${YELLOW}  ⚠ .env не найден — создаю из .env.example${NC}"
        if [ "$DRY_RUN" = false ]; then
            cp "$TARGET_ENV_EXAMPLE" "$TARGET_ENV"
        fi
    else
        echo -e "${YELLOW}  ⚠ .env и .env.example не найдены — создаю пустой .env${NC}"
        if [ "$DRY_RUN" = false ]; then
            touch "$TARGET_ENV"
        fi
    fi
fi

# Читаем .env.docker и раскладываем переменные по двум временным файлам:
# replace.list — ключи, которые нужно ЗАМЕНИТЬ в .env
# add.list     — ключи, которые нужно ДОБАВИТЬ если отсутствуют
REPLACE_LIST="$(mktemp)"
ADD_LIST="$(mktemp)"

CURRENT_MODE="ADD"
while IFS= read -r line; do
    # Определяем режим из комментариев
    if echo "$line" | grep -q '\[REPLACE\]'; then
        CURRENT_MODE="REPLACE"
    elif echo "$line" | grep -q '\[ADD\]'; then
        CURRENT_MODE="ADD"
    fi

    # Пропускаем комментарии и пустые строки
    echo "$line" | grep -q '^[[:space:]]*#' && continue
    [ -z "${line// }" ] && continue

    # Извлекаем ключ
    KEY="${line%%=*}"
    [ -z "$KEY" ] && continue

    if [ "$CURRENT_MODE" = "REPLACE" ]; then
        echo "$line" >> "$REPLACE_LIST"
    else
        echo "$line" >> "$ADD_LIST"
    fi
done < "$DOCKER_ENV_FILE"

REPLACED=0
ADDED=0
SKIPPED=0

# --- Применяем REPLACE ---
TEMP_ENV="$(mktemp)"
cp "$TARGET_ENV" "$TEMP_ENV"

while IFS= read -r line; do
    KEY="${line%%=*}"
    [ -z "$KEY" ] && continue

    if grep -q "^${KEY}=" "$TEMP_ENV" 2>/dev/null; then
        OLD_VALUE=$(grep "^${KEY}=" "$TEMP_ENV" | head -1)
        if [ "$OLD_VALUE" != "$line" ]; then
            if [ "$DRY_RUN" = false ]; then
                sed -i.bak "s|^${KEY}=.*|${line}|" "$TEMP_ENV"
                rm -f "${TEMP_ENV}.bak"
            fi
            echo -e "${CYAN}  ↺ Заменено:  ${KEY}${NC}"
            REPLACED=$((REPLACED + 1))
        else
            echo -e "${GREEN}  = Совпадает: ${KEY}${NC}"
            SKIPPED=$((SKIPPED + 1))
        fi
    else
        # Ключ отсутствует — добавим через ADD-логику ниже
        echo "$line" >> "$ADD_LIST"
    fi
done < "$REPLACE_LIST"

if [ "$DRY_RUN" = false ]; then
    cp "$TEMP_ENV" "$TARGET_ENV"
fi
rm -f "$TEMP_ENV" "$REPLACE_LIST"

# --- Применяем ADD (только отсутствующие ключи) ---
ADD_HEADER_WRITTEN=false

while IFS= read -r line; do
    KEY="${line%%=*}"
    [ -z "$KEY" ] && continue

    if ! grep -q "^${KEY}=" "$TARGET_ENV" 2>/dev/null; then
        if [ "$ADD_HEADER_WRITTEN" = false ] && [ "$DRY_RUN" = false ]; then
            {
                echo ""
                echo "# =============================================="
                echo "# Docker Environment"
                echo "# =============================================="
            } >> "$TARGET_ENV"
            ADD_HEADER_WRITTEN=true
        fi
        echo -e "${GREEN}  + Добавлено: ${KEY}${NC}"
        if [ "$DRY_RUN" = false ]; then
            echo "$line" >> "$TARGET_ENV"
        fi
        ADDED=$((ADDED + 1))
    else
        echo -e "${GREEN}  = Уже есть:  ${KEY}${NC}"
        SKIPPED=$((SKIPPED + 1))
    fi
done < "$ADD_LIST"

rm -f "$ADD_LIST"

echo ""

# --- 3. Итоги ---

echo -e "${BLUE}[3/3] Готово!${NC}"
echo ""
echo -e "${GREEN}✓ Docker-файлы скопированы в: $TARGET_DIR${NC}"
echo -e "${GREEN}✓ .env: заменено=${REPLACED}, добавлено=${ADDED}, без изменений=${SKIPPED}${NC}"
echo ""
echo -e "${YELLOW}Следующие шаги:${NC}"
echo -e "  1. Перейдите в проект:   ${CYAN}cd $TARGET_DIR${NC}"
echo -e "  2. Откройте .env и задайте уникальный COMPOSE_PROJECT_NAME"
echo -e "  3. Проверьте порты:      ${CYAN}make check-config${NC}"
echo -e "  4. Запустите окружение:  ${CYAN}make dev${NC}"
echo ""
echo -e "${BLUE}================================================${NC}"


