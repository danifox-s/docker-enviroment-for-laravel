# ==============================================
# Laravel Docker Development Environment
# ==============================================

.PHONY: help up down build restart logs shell composer artisan test migrate fresh install clean ps

# Цвета для красивого вывода
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m # No Color

# По умолчанию выводим help
.DEFAULT_GOAL := help

## —— Помощь ——————————————————————————————————
help: ## Показать эту справку
	@echo "$(BLUE)Laravel Docker Environment$(NC)"
	@echo ""
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'
	@echo ""

## —— Инициализация проекта —————————————————
init-project: ## Инициализировать новый проект (создать .env, установить зависимости)
	@echo "$(BLUE)Инициализация нового проекта...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)✓ Создан файл .env из .env.example$(NC)"; \
		echo "$(RED)⚠ ВАЖНО: Отредактируйте .env и измените:$(NC)"; \
		echo "  - COMPOSE_PROJECT_NAME (уникальное имя проекта)"; \
		echo "  - APP_PORT (если 8000 занят)"; \
		echo "  - PHPMYADMIN_PORT (если 8080 занят)"; \
	else \
		echo "$(RED)✗ Файл .env уже существует$(NC)"; \
	fi

check-config: ## Проверить конфигурацию проекта
	@echo "$(BLUE)Проверка конфигурации проекта...$(NC)"
	@if [ -f .env ]; then \
		echo "$(GREEN)Текущая конфигурация:$(NC)"; \
		echo "Имя проекта: $$(grep COMPOSE_PROJECT_NAME .env | cut -d '=' -f2)"; \
		echo "APP порт: $$(grep APP_PORT .env | cut -d '=' -f2)"; \
		echo "PHPMyAdmin порт: $$(grep PHPMYADMIN_PORT .env | cut -d '=' -f2)"; \
		echo ""; \
		echo "$(BLUE)Проверка портов...$(NC)"; \
		APP_PORT=$$(grep APP_PORT .env | cut -d '=' -f2); \
		if lsof -Pi :$$APP_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then \
			echo "$(RED)⚠ Порт $$APP_PORT занят!$(NC)"; \
		else \
			echo "$(GREEN)✓ Порт $$APP_PORT свободен$(NC)"; \
		fi; \
		PMA_PORT=$$(grep PHPMYADMIN_PORT .env | cut -d '=' -f2); \
		if lsof -Pi :$$PMA_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then \
			echo "$(RED)⚠ Порт $$PMA_PORT занят!$(NC)"; \
		else \
			echo "$(GREEN)✓ Порт $$PMA_PORT свободен$(NC)"; \
		fi \
	else \
		echo "$(RED)✗ Файл .env не найден. Запустите 'make init-project'$(NC)"; \
	fi

## —— Docker ————————————————————————————————
up: ## Запустить контейнеры (development)
	@echo "$(BLUE)Запуск контейнеров в режиме разработки...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(RED)⚠ Файл .env не найден! Создайте его из .env.example$(NC)"; \
		echo "$(BLUE)Копирую .env.example в .env...$(NC)"; \
		cp .env.example .env; \
	fi
	docker compose up -d
	@echo "$(GREEN)✓ Контейнеры запущены$(NC)"
	@echo "Приложение: http://localhost:$$(grep APP_PORT .env 2>/dev/null | cut -d '=' -f2 || echo '8000')"
	@echo "PHPMyAdmin: http://localhost:$$(grep PHPMYADMIN_PORT .env 2>/dev/null | cut -d '=' -f2 || echo '8080') (используйте 'make up-tools')"

up-prod: ## Запустить контейнеры (production с отдельным compose файлом)
	@echo "$(BLUE)Запуск контейнеров в production режиме...$(NC)"
	docker compose -f docker-compose.prod.yml up -d
	@echo "$(GREEN)✓ Контейнеры запущены в production режиме$(NC)"

up-prod-simple: ## Запустить контейнеры (production через переменную)
	@echo "$(BLUE)Запуск контейнеров в production режиме (simple)...$(NC)"
	PHP_BUILD_STAGE=production docker compose up -d
	@echo "$(GREEN)✓ Контейнеры запущены в production режиме$(NC)"

up-tools: ## Запустить контейнеры с PHPMyAdmin
	@echo "$(BLUE)Запуск контейнеров с инструментами...$(NC)"
	docker compose --profile tools up -d
	@echo "$(GREEN)✓ Контейнеры запущены$(NC)"
	@echo "Приложение: http://localhost:$$(grep APP_PORT .env 2>/dev/null | cut -d '=' -f2 || echo '8000')"
	@echo "PHPMyAdmin: http://localhost:$$(grep PHPMYADMIN_PORT .env 2>/dev/null | cut -d '=' -f2 || echo '8080')"

up-full: ## Запустить все контейнеры (включая worker и scheduler)
	@echo "$(BLUE)Запуск всех контейнеров...$(NC)"
	docker compose --profile worker --profile scheduler up -d
	@echo "$(GREEN)✓ Все контейнеры запущены$(NC)"

down: ## Остановить контейнеры
	@echo "$(BLUE)Остановка контейнеров...$(NC)"
	docker compose down
	@echo "$(GREEN)✓ Контейнеры остановлены$(NC)"

down-prod: ## Остановить production контейнеры
	@echo "$(BLUE)Остановка production контейнеров...$(NC)"
	docker compose -f docker-compose.prod.yml down
	@echo "$(GREEN)✓ Production контейнеры остановлены$(NC)"

down-all: ## Остановить все контейнеры и удалить volumes
	@echo "$(RED)Остановка контейнеров и удаление данных...$(NC)"
	docker compose down -v
	docker compose -f docker-compose.prod.yml down -v 2>/dev/null || true
	@echo "$(GREEN)✓ Контейнеры остановлены, данные удалены$(NC)"

build: ## Пересобрать образы
	@echo "$(BLUE)Пересборка образов...$(NC)"
	docker compose build --no-cache
	@echo "$(GREEN)✓ Образы пересобраны$(NC)"

build-prod: ## Пересобрать образы для production
	@echo "$(BLUE)Пересборка образов для production...$(NC)"
	docker compose -f docker-compose.prod.yml build --no-cache
	@echo "$(GREEN)✓ Production образы пересобраны$(NC)"

restart: ## Перезапустить контейнеры
	@echo "$(BLUE)Перезапуск контейнеров...$(NC)"
	docker compose restart
	@echo "$(GREEN)✓ Контейнеры перезапущены$(NC)"

ps: ## Показать статус контейнеров
	@docker compose ps

logs: ## Показать логи всех контейнеров
	docker compose logs -f

logs-app: ## Показать логи PHP контейнера
	docker compose logs -f app

logs-webserver: ## Показать логи Nginx контейнера
	docker compose logs -f webserver

logs-mysql: ## Показать логи MySQL контейнера
	docker compose logs -f mysql

## —— Shell доступ ———————————————————————————
shell: ## Войти в PHP контейнер
	docker compose exec app sh

shell-root: ## Войти в PHP контейнер как root
	docker compose exec -u root app sh

shell-mysql: ## Войти в MySQL контейнер
	docker compose exec mysql mysql -u${DB_USERNAME:-laravel} -p${DB_PASSWORD:-secret} ${DB_DATABASE:-laravel}

## —— Laravel ————————————————————————————————
install: ## Установить зависимости и подготовить приложение
	@echo "$(BLUE)Установка зависимостей...$(NC)"
	docker compose exec app composer install
	@make cache-clear
	@make key-generate
	@make migrate
	@echo "$(GREEN)✓ Приложение готово к работе$(NC)"

composer: ## Выполнить composer команду (make composer CMD="require package")
	docker compose exec app composer $(CMD)

artisan: ## Выполнить artisan команду (make artisan CMD="route:list")
	docker compose exec app php artisan $(CMD)

test: ## Запустить тесты
	docker compose exec app php artisan test

test-coverage: ## Запустить тесты с покрытием
	docker compose exec app php artisan test --coverage

migrate: ## Выполнить миграции
	@echo "$(BLUE)Выполнение миграций...$(NC)"
	docker compose exec app php artisan migrate --force
	@echo "$(GREEN)✓ Миграции выполнены$(NC)"

migrate-fresh: ## Пересоздать БД и выполнить миграции
	@echo "$(RED)Пересоздание базы данных...$(NC)"
	docker compose exec app php artisan migrate:fresh --seed --force
	@echo "$(GREEN)✓ База данных пересоздана$(NC)"

seed: ## Запустить сидеры
	docker compose exec app php artisan db:seed

key-generate: ## Сгенерировать APP_KEY
	docker compose exec app php artisan key:generate

cache-clear: ## Очистить весь кеш
	@echo "$(BLUE)Очистка кеша...$(NC)"
	docker compose exec app php artisan cache:clear
	docker compose exec app php artisan config:clear
	docker compose exec app php artisan route:clear
	docker compose exec app php artisan view:clear
	@echo "$(GREEN)✓ Кеш очищен$(NC)"

cache-optimize: ## Оптимизировать кеш для production
	@echo "$(BLUE)Оптимизация кеша...$(NC)"
	docker compose exec app php artisan config:cache
	docker compose exec app php artisan route:cache
	docker compose exec app php artisan view:cache
	docker compose exec app composer dump-autoload --optimize
	@echo "$(GREEN)✓ Кеш оптимизирован$(NC)"

queue-work: ## Запустить обработку очереди
	docker compose exec app php artisan queue:work

## —— Инструменты —————————————————————————————
phpmyadmin-up:   # Запустить PHPMyAdmin
	@echo "$(BLUE)Запуск PHPMyAdmin...$(NC)"
	docker compose --profile tools up -d phpmyadmin
	@echo "$(GREEN)✓ PHPMyAdmin: http://localhost:8080$(NC)"

health-check: ## Проверить состояние системы
	@./docker-health-check.sh

fix-permissions: ## Исправить права доступа
	@echo "$(BLUE)Исправление прав доступа...$(NC)"
	docker compose exec -u root app chown -R www-data:www-data /var/www/html
	docker compose exec -u root app chmod -R 775 /var/www/html/storage
	docker compose exec -u root app chmod -R 775 /var/www/html/bootstrap/cache
	@echo "$(GREEN)✓ Права доступа исправлены$(NC)"

clean: ## Очистить Docker систему
	@echo "$(RED)Очистка Docker системы...$(NC)"
	docker system prune -af --volumes
	@echo "$(GREEN)✓ Docker система очищена$(NC)"

## —— Быстрые команды ————————————————————————
dev: ## Быстрый старт для разработки
	@make build
	@make up
	@make install
	@echo "$(GREEN)✓ Окружение разработки готово!$(NC)"
	@echo "Приложение: http://localhost:$$(grep APP_PORT .env 2>/dev/null | cut -d '=' -f2 || echo '8000')"
	@echo "PHPMyAdmin: make phpmyadmin-up"

prod-deploy: ## Развертывание production
	@echo "$(BLUE)Развертывание production окружения...$(NC)"
	@make build-prod
	@make up-prod
	@sleep 5
	@echo "$(BLUE)Ожидание готовности сервисов...$(NC)"
	@docker compose -f docker-compose.prod.yml exec -T app php artisan config:cache
	@docker compose -f docker-compose.prod.yml exec -T app php artisan route:cache
	@docker compose -f docker-compose.prod.yml exec -T app php artisan view:cache
	@echo "$(GREEN)✓ Production развернут!$(NC)"
	@echo "Приложение доступно на порту 80"

