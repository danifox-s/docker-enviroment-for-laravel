#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}  Docker Health Check${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

# Check Docker
echo -e "${YELLOW}Checking Docker...${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✓${NC} Docker installed: $DOCKER_VERSION"
else
    echo -e "${RED}✗${NC} Docker is not installed"
    exit 1
fi

# Check Docker Compose
echo -e "${YELLOW}Checking Docker Compose...${NC}"
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    echo -e "${GREEN}✓${NC} Docker Compose installed: $COMPOSE_VERSION"
else
    echo -e "${RED}✗${NC} Docker Compose is not installed"
    exit 1
fi

# Check running containers
echo ""
echo -e "${YELLOW}Checking containers...${NC}"
CONTAINERS=$(docker compose ps --format json 2>/dev/null | jq -r '.Name' 2>/dev/null)

if [ -z "$CONTAINERS" ]; then
    echo -e "${YELLOW}⚠${NC} No containers running"
    echo -e "${BLUE}Run: make up${NC}"
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

# Check ports
echo ""
echo -e "${YELLOW}Checking ports...${NC}"

check_port() {
    local port=$1
    local service=$2
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Port $port ($service) is available"
    else
        echo -e "${RED}✗${NC} Port $port ($service) is not available"
    fi
}

APP_PORT_VAL=$(grep "^APP_PORT=" .env 2>/dev/null | cut -d '=' -f2 || echo "8000")
PMA_PORT_VAL=$(grep "^PHPMYADMIN_PORT=" .env 2>/dev/null | cut -d '=' -f2 || echo "8080")
check_port "${APP_PORT_VAL:-8000}" "Nginx/App"
check_port 3306 "MySQL (if exposed)"
check_port "${PMA_PORT_VAL:-8080}" "PHPMyAdmin (if running)"

# Check volumes
echo ""
echo -e "${YELLOW}Checking volumes...${NC}"
PROJECT_NAME=$(grep "^COMPOSE_PROJECT_NAME=" .env 2>/dev/null | cut -d '=' -f2 || echo "")
VOLUMES=$(docker volume ls --filter name="${PROJECT_NAME}" --format "{{.Name}}" 2>/dev/null)
if [ -z "$VOLUMES" ]; then
    echo -e "${YELLOW}⚠${NC} No volumes found"
else
    while IFS= read -r volume; do
        echo -e "${GREEN}✓${NC} $volume"
    done <<< "$VOLUMES"
fi

# Check .env file
echo ""
echo -e "${YELLOW}Checking configuration...${NC}"
if [ -f ".env" ]; then
    echo -e "${GREEN}✓${NC} .env file exists"

    # Check critical variables
    if grep -q "APP_KEY=base64:" .env; then
        echo -e "${GREEN}✓${NC} APP_KEY is set"
    else
        echo -e "${RED}✗${NC} APP_KEY is not set (run: docker compose exec app php artisan key:generate)"
    fi

    if grep -q "DB_HOST=mysql" .env; then
        echo -e "${GREEN}✓${NC} DB_HOST is configured for Docker"
    else
        echo -e "${YELLOW}⚠${NC} DB_HOST may not be configured for Docker"
    fi

    if grep -q "REDIS_HOST=redis" .env; then
        echo -e "${GREEN}✓${NC} REDIS_HOST is configured for Docker"
    else
        echo -e "${YELLOW}⚠${NC} REDIS_HOST may not be configured for Docker"
    fi
else
    echo -e "${RED}✗${NC} .env file not found (copy from .env.example)"
fi

# Check logs for errors
echo ""
echo -e "${YELLOW}Checking logs for critical errors...${NC}"
if [ -f "storage/logs/laravel.log" ]; then
    ERROR_COUNT=$(grep -c "ERROR" storage/logs/laravel.log 2>/dev/null || echo "0")
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}⚠${NC} Errors found in logs: $ERROR_COUNT"
        echo -e "${BLUE}Check: storage/logs/laravel.log${NC}"
    else
        echo -e "${GREEN}✓${NC} No critical errors in logs"
    fi
else
    echo -e "${YELLOW}⚠${NC} Log file not found"
fi

# Check DB connection
echo ""
echo -e "${YELLOW}Checking DB connection...${NC}"
if docker compose ps | grep -q "app.*Up\|app.*running"; then
    DB_CHECK=$(docker compose exec -T app php artisan migrate:status 2>&1)
    if echo "$DB_CHECK" | grep -q "Migration name"; then
        echo -e "${GREEN}✓${NC} DB connection is working"
    else
        echo -e "${RED}✗${NC} Could not connect to DB"
        echo -e "${BLUE}Check: make logs-mysql${NC}"
    fi
else
    echo -e "${YELLOW}⚠${NC} App container is not running"
fi

# Summary
echo ""
echo -e "${BLUE}==================================${NC}"
echo -e "${GREEN}Health check complete!${NC}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "  make help       - Show all commands"
echo -e "  make logs       - View logs"
echo -e "  make ps         - Container status"
echo -e "  make shell      - Enter container"
echo -e "${BLUE}==================================${NC}"
