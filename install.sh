#!/bin/bash

# ==============================================
# Laravel Docker Environment Installer
# ==============================================
# Copies Docker files into your Laravel project and merges .env.docker into .env
#
# Usage:
#   ./install.sh                    # install into current directory
#   ./install.sh /path/to/project   # install into specified directory
#   ./install.sh . --dry-run        # preview changes without applying them

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Directory of this script (source of Docker files)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Target directory
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# Dry-run mode
DRY_RUN=false
if [[ "$1" == "--dry-run" ]] || [[ "$2" == "--dry-run" ]]; then
    DRY_RUN=true
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Laravel Docker Environment Installer${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${CYAN}Source:${NC} $SCRIPT_DIR"
echo -e "${CYAN}Target:${NC} $TARGET_DIR"
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}  [DRY RUN — no changes will be applied]${NC}"
fi
echo ""

# --- Checks ---

if [ "$SCRIPT_DIR" = "$TARGET_DIR" ]; then
    echo -e "${RED}✗ Cannot install into itself. Specify the path to your Laravel project.${NC}"
    echo "  Example: ./install.sh ~/projects/my-laravel-app"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}✗ Directory not found: $TARGET_DIR${NC}"
    exit 1
fi

# --- Confirmation prompt ---

if [ "$DRY_RUN" = false ]; then
    echo -e "${YELLOW}What will happen:${NC}"
    echo -e "  • Files to be copied: ${CYAN}docker/, docker-compose.yml, docker-compose.prod.yml, Makefile, .dockerignore, .env.docker, README.md (as DOCKER.md)${NC}"
    echo -e "  • The following will be ${CYAN}replaced${NC} in .env: DB_HOST, DB_PORT, DB_DATABASE, DB_USERNAME, DB_PASSWORD,"
    echo -e "    REDIS_HOST, REDIS_CLIENT, SESSION_DRIVER, CACHE_STORE, QUEUE_CONNECTION"
    echo -e "  • The following will be ${CYAN}added${NC} to .env: COMPOSE_PROJECT_NAME, APP_PORT, DB_PORT_EXTERNAL, Xdebug and PHP variables"
    echo ""
    echo -e "${YELLOW}Existing files will be overwritten without the ability to undo.${NC}"
    echo ""
    echo -e "Install Docker environment into ${CYAN}$TARGET_DIR${NC}?"
    echo -e "Type ${GREEN}yes${NC} to confirm: "
    read -r CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${RED}Installation cancelled.${NC}"
        exit 0
    fi
    echo ""
fi

# --- Functions ---

copy_item() {
    local src="$1"
    local dst="$2"
    if [ -e "$dst" ]; then
        echo -e "${YELLOW}  ~ Already exists (overwriting): $(basename "$dst")${NC}"
    else
        echo -e "${GREEN}  + Copying: $(basename "$dst")${NC}"
    fi
    if [ "$DRY_RUN" = false ]; then
        if [ -d "$src" ]; then
            cp -r "$src" "$dst"
        else
            cp "$src" "$dst"
        fi
    fi
}

# --- 1. Copy Docker files ---

echo -e "${BLUE}[1/3] Copying Docker files...${NC}"

copy_item "$SCRIPT_DIR/docker"                   "$TARGET_DIR/docker"
copy_item "$SCRIPT_DIR/docker-compose.yml"       "$TARGET_DIR/docker-compose.yml"
copy_item "$SCRIPT_DIR/docker-compose.prod.yml"  "$TARGET_DIR/docker-compose.prod.yml"
copy_item "$SCRIPT_DIR/.dockerignore"            "$TARGET_DIR/.dockerignore"
copy_item "$SCRIPT_DIR/Makefile"                 "$TARGET_DIR/Makefile"
copy_item "$SCRIPT_DIR/docker-health-check.sh"   "$TARGET_DIR/docker-health-check.sh"
copy_item "$SCRIPT_DIR/.env.docker"              "$TARGET_DIR/.env.docker"
copy_item "$SCRIPT_DIR/README.md"                "$TARGET_DIR/DOCKER.md"

if [ "$DRY_RUN" = false ]; then
    chmod +x "$TARGET_DIR/docker-health-check.sh"
fi

echo ""

# --- 2. Merge .env.docker → .env ---

echo -e "${BLUE}[2/3] Processing environment variables...${NC}"

DOCKER_ENV_FILE="$SCRIPT_DIR/.env.docker"
TARGET_ENV="$TARGET_DIR/.env"
TARGET_ENV_EXAMPLE="$TARGET_DIR/.env.example"

# If .env does not exist — create from .env.example
if [ ! -f "$TARGET_ENV" ]; then
    if [ -f "$TARGET_ENV_EXAMPLE" ]; then
        echo -e "${YELLOW}  ⚠ .env not found — creating from .env.example${NC}"
        if [ "$DRY_RUN" = false ]; then
            cp "$TARGET_ENV_EXAMPLE" "$TARGET_ENV"
        fi
    else
        echo -e "${YELLOW}  ⚠ Neither .env nor .env.example found — creating empty .env${NC}"
        if [ "$DRY_RUN" = false ]; then
            touch "$TARGET_ENV"
        fi
    fi
fi

# Read .env.docker and split variables into two temp files:
# replace.list — keys to REPLACE in .env
# add.list     — keys to ADD if missing
REPLACE_LIST="$(mktemp)"
ADD_LIST="$(mktemp)"

CURRENT_MODE="ADD"
while IFS= read -r line; do
    # Determine mode from comments
    if echo "$line" | grep -q '\[REPLACE\]'; then
        CURRENT_MODE="REPLACE"
    elif echo "$line" | grep -q '\[ADD\]'; then
        CURRENT_MODE="ADD"
    fi

    # Skip comments and empty lines
    echo "$line" | grep -q '^[[:space:]]*#' && continue
    [ -z "${line// }" ] && continue

    # Extract key
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

# --- Apply REPLACE ---
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
            echo -e "${CYAN}  ↺ Replaced:  ${KEY}${NC}"
            REPLACED=$((REPLACED + 1))
        else
            echo -e "${GREEN}  = Matches:   ${KEY}${NC}"
            SKIPPED=$((SKIPPED + 1))
        fi
    else
        # Key is missing — will be added via ADD logic below
        echo "$line" >> "$ADD_LIST"
    fi
done < "$REPLACE_LIST"

if [ "$DRY_RUN" = false ]; then
    cp "$TEMP_ENV" "$TARGET_ENV"
fi
rm -f "$TEMP_ENV" "$REPLACE_LIST"

# --- Apply ADD (only missing keys) ---
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
        echo -e "${GREEN}  + Added:     ${KEY}${NC}"
        if [ "$DRY_RUN" = false ]; then
            echo "$line" >> "$TARGET_ENV"
        fi
        ADDED=$((ADDED + 1))
    else
        echo -e "${GREEN}  = Exists:    ${KEY}${NC}"
        SKIPPED=$((SKIPPED + 1))
    fi
done < "$ADD_LIST"

rm -f "$ADD_LIST"

echo ""

# --- 3. Summary ---

echo -e "${BLUE}[3/3] Done!${NC}"
echo ""
echo -e "${GREEN}✓ Docker files copied to: $TARGET_DIR${NC}"
echo -e "${GREEN}✓ .env: replaced=${REPLACED}, added=${ADDED}, unchanged=${SKIPPED}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Go to your project:   ${CYAN}cd $TARGET_DIR${NC}"
echo -e "  2. Open .env and set a unique COMPOSE_PROJECT_NAME"
echo -e "  3. Set your DB credentials (DB_DATABASE, DB_USERNAME, DB_PASSWORD)"
echo -e "  4. Check ports:          ${CYAN}make check-config${NC}"
echo -e "  5. Start the environment: ${CYAN}make dev${NC}"
echo ""
echo -e "${BLUE}================================================${NC}"
