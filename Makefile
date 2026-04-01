# ==============================================
# Laravel Docker Development Environment
# ==============================================

.PHONY: help up down build restart logs shell composer artisan test migrate fresh install clean ps

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m

# Default target
.DEFAULT_GOAL := help

## —— Help ————————————————————————————————————
help: ## Show this help
	@echo "$(BLUE)Laravel Docker Environment$(NC)"
	@echo ""
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'
	@echo ""

## —— Project initialization ————————————————
init-project: ## Initialize a new project (create .env, install dependencies)
	@echo "$(BLUE)Initializing new project...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)✓ Created .env from .env.example$(NC)"; \
		echo "$(RED)⚠ IMPORTANT: Edit .env and change:$(NC)"; \
		echo "  - COMPOSE_PROJECT_NAME (unique project name)"; \
		echo "  - APP_PORT (if 8000 is taken)"; \
		echo "  - PHPMYADMIN_PORT (if 8080 is taken)"; \
	else \
		echo "$(RED)✗ .env already exists$(NC)"; \
	fi

check-config: ## Check project configuration
	@echo "$(BLUE)Checking project configuration...$(NC)"
	@if [ -f .env ]; then \
		echo "$(GREEN)Current configuration:$(NC)"; \
		echo "Project name: $$(grep COMPOSE_PROJECT_NAME .env | cut -d '=' -f2)"; \
		echo "APP port: $$(grep APP_PORT .env | cut -d '=' -f2)"; \
		echo "PHPMyAdmin port: $$(grep PHPMYADMIN_PORT .env | cut -d '=' -f2)"; \
		echo ""; \
		echo "$(BLUE)Checking ports...$(NC)"; \
		APP_PORT=$$(grep APP_PORT .env | cut -d '=' -f2); \
		if lsof -Pi :$$APP_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then \
			echo "$(RED)⚠ Port $$APP_PORT is in use!$(NC)"; \
		else \
			echo "$(GREEN)✓ Port $$APP_PORT is free$(NC)"; \
		fi; \
		PMA_PORT=$$(grep PHPMYADMIN_PORT .env | cut -d '=' -f2); \
		if lsof -Pi :$$PMA_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then \
			echo "$(RED)⚠ Port $$PMA_PORT is in use!$(NC)"; \
		else \
			echo "$(GREEN)✓ Port $$PMA_PORT is free$(NC)"; \
		fi \
	else \
		echo "$(RED)✗ .env not found. Run 'make init-project'$(NC)"; \
	fi

## —— Docker ————————————————————————————————
up: ## Start containers (development)
	@echo "$(BLUE)Starting containers in development mode...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(RED)⚠ .env not found! Creating from .env.example...$(NC)"; \
		cp .env.example .env; \
	fi
	docker compose up -d
	@echo "$(GREEN)✓ Containers started$(NC)"
	@echo "App: http://localhost:$$(grep APP_PORT .env 2>/dev/null | cut -d '=' -f2 || echo '8000')"
	@echo "PHPMyAdmin: http://localhost:$$(grep PHPMYADMIN_PORT .env 2>/dev/null | cut -d '=' -f2 || echo '8080') (use 'make up-tools')"

up-prod: ## Start containers (production with separate compose file)
	@echo "$(BLUE)Starting containers in production mode...$(NC)"
	docker compose -f docker-compose.prod.yml up -d
	@echo "$(GREEN)✓ Containers started in production mode$(NC)"

up-prod-simple: ## Start containers (production via variable)
	@echo "$(BLUE)Starting containers in production mode (simple)...$(NC)"
	PHP_BUILD_STAGE=production docker compose up -d
	@echo "$(GREEN)✓ Containers started in production mode$(NC)"

up-tools: ## Start containers with PHPMyAdmin
	@echo "$(BLUE)Starting containers with tools...$(NC)"
	docker compose --profile tools up -d
	@echo "$(GREEN)✓ Containers started$(NC)"
	@echo "App: http://localhost:$$(grep APP_PORT .env 2>/dev/null | cut -d '=' -f2 || echo '8000')"
	@echo "PHPMyAdmin: http://localhost:$$(grep PHPMYADMIN_PORT .env 2>/dev/null | cut -d '=' -f2 || echo '8080')"

up-full: ## Start all containers (including worker and scheduler)
	@echo "$(BLUE)Starting all containers...$(NC)"
	docker compose --profile worker --profile scheduler up -d
	@echo "$(GREEN)✓ All containers started$(NC)"

down: ## Stop containers
	@echo "$(BLUE)Stopping containers...$(NC)"
	docker compose down
	@echo "$(GREEN)✓ Containers stopped$(NC)"

down-prod: ## Stop production containers
	@echo "$(BLUE)Stopping production containers...$(NC)"
	docker compose -f docker-compose.prod.yml down
	@echo "$(GREEN)✓ Production containers stopped$(NC)"

down-all: ## Stop all containers and remove volumes
	@echo "$(RED)Stopping containers and removing data...$(NC)"
	docker compose down -v
	docker compose -f docker-compose.prod.yml down -v 2>/dev/null || true
	@echo "$(GREEN)✓ Containers stopped, data removed$(NC)"

build: ## Rebuild images
	@echo "$(BLUE)Rebuilding images...$(NC)"
	docker compose build --no-cache
	@echo "$(GREEN)✓ Images rebuilt$(NC)"

build-prod: ## Rebuild images for production
	@echo "$(BLUE)Rebuilding images for production...$(NC)"
	docker compose -f docker-compose.prod.yml build --no-cache
	@echo "$(GREEN)✓ Production images rebuilt$(NC)"

restart: ## Restart containers
	@echo "$(BLUE)Restarting containers...$(NC)"
	docker compose restart
	@echo "$(GREEN)✓ Containers restarted$(NC)"

ps: ## Show container status
	@docker compose ps

logs: ## Show logs for all containers
	docker compose logs -f

logs-app: ## Show PHP container logs
	docker compose logs -f app

logs-webserver: ## Show Nginx container logs
	docker compose logs -f webserver

logs-mysql: ## Show MySQL container logs
	docker compose logs -f mysql

## —— Shell access ————————————————————————
shell: ## Enter the PHP container
	docker compose exec app sh

shell-root: ## Enter the PHP container as root
	docker compose exec -u root app sh

shell-mysql: ## Enter the MySQL container
	docker compose exec mysql mysql -u${DB_USERNAME:-laravel} -p${DB_PASSWORD:-secret} ${DB_DATABASE:-laravel}

## —— Laravel ————————————————————————————
install: ## Install dependencies and prepare the application
	@echo "$(BLUE)Installing dependencies...$(NC)"
	docker compose exec app composer install
	@make cache-clear
	@make key-generate
	@make migrate
	@echo "$(GREEN)✓ Application is ready$(NC)"

composer: ## Run a composer command (make composer CMD="require package")
	docker compose exec app composer $(CMD)

artisan: ## Run an artisan command (make artisan CMD="route:list")
	docker compose exec app php artisan $(CMD)

test: ## Run tests
	docker compose exec app php artisan test

test-coverage: ## Run tests with coverage
	docker compose exec app php artisan test --coverage

migrate: ## Run migrations
	@echo "$(BLUE)Running migrations...$(NC)"
	docker compose exec app php artisan migrate --force
	@echo "$(GREEN)✓ Migrations complete$(NC)"

migrate-fresh: ## Recreate DB and run migrations
	@echo "$(RED)Recreating database...$(NC)"
	docker compose exec app php artisan migrate:fresh --seed --force
	@echo "$(GREEN)✓ Database recreated$(NC)"

seed: ## Run seeders
	docker compose exec app php artisan db:seed

key-generate: ## Generate APP_KEY
	docker compose exec app php artisan key:generate

cache-clear: ## Clear all cache
	@echo "$(BLUE)Clearing cache...$(NC)"
	docker compose exec app php artisan cache:clear
	docker compose exec app php artisan config:clear
	docker compose exec app php artisan route:clear
	docker compose exec app php artisan view:clear
	@echo "$(GREEN)✓ Cache cleared$(NC)"

cache-optimize: ## Optimize cache for production
	@echo "$(BLUE)Optimizing cache...$(NC)"
	docker compose exec app php artisan config:cache
	docker compose exec app php artisan route:cache
	docker compose exec app php artisan view:cache
	docker compose exec app composer dump-autoload --optimize
	@echo "$(GREEN)✓ Cache optimized$(NC)"

queue-work: ## Start queue worker
	docker compose exec app php artisan queue:work

## —— Tools ———————————————————————————————
phpmyadmin-up:   # Start PHPMyAdmin
	@echo "$(BLUE)Starting PHPMyAdmin...$(NC)"
	docker compose --profile tools up -d phpmyadmin
	@echo "$(GREEN)✓ PHPMyAdmin: http://localhost:8080$(NC)"

health-check: ## Check system health
	@./docker-health-check.sh

fix-permissions: ## Fix file permissions
	@echo "$(BLUE)Fixing file permissions...$(NC)"
	docker compose exec -u root app chown -R www-data:www-data /var/www/html
	docker compose exec -u root app chmod -R 775 /var/www/html/storage
	docker compose exec -u root app chmod -R 775 /var/www/html/bootstrap/cache
	@echo "$(GREEN)✓ Permissions fixed$(NC)"

clean: ## Clean Docker system
	@echo "$(RED)Cleaning Docker system...$(NC)"
	docker system prune -af --volumes
	@echo "$(GREEN)✓ Docker system cleaned$(NC)"

## —— Quick commands ——————————————————————
dev: ## Quick start for development
	@make build
	@make up
	@make install
	@echo "$(GREEN)✓ Development environment is ready!$(NC)"
	@echo "App: http://localhost:$$(grep APP_PORT .env 2>/dev/null | cut -d '=' -f2 || echo '8000')"
	@echo "PHPMyAdmin: make phpmyadmin-up"

prod-deploy: ## Deploy to production
	@echo "$(BLUE)Deploying production environment...$(NC)"
	@make build-prod
	@make up-prod
	@sleep 5
	@echo "$(BLUE)Waiting for services to be ready...$(NC)"
	@docker compose -f docker-compose.prod.yml exec -T app php artisan config:cache
	@docker compose -f docker-compose.prod.yml exec -T app php artisan route:cache
	@docker compose -f docker-compose.prod.yml exec -T app php artisan view:cache
	@echo "$(GREEN)✓ Production deployed!$(NC)"
	@echo "App is available on port 80"
