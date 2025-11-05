# Multi-stage build для development и production
FROM php:8.4-fpm-alpine as base

# Установка системных зависимостей (Alpine Linux)
RUN apk add --no-cache \
    git \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    oniguruma-dev \
    libxml2-dev \
    zip \
    unzip \
    libzip-dev \
    icu-dev \
    mysql-client \
    shadow \
    bash \
    && rm -rf /var/cache/apk/*

# Установка PHP расширений
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    intl \
    zip \
    opcache

# Redis extension
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# Установка Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Создание пользователя для безопасности
RUN groupmod -g 1000 www-data \
    && usermod -u 1000 -g www-data www-data

# Копирование конфигураций
COPY docker/php/conf.d/php.ini /usr/local/etc/php/php.ini

WORKDIR /var/www/html

# Development stage
FROM base as development

# Установка Xdebug
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS linux-headers \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apk del .build-deps

# Копирование Xdebug конфигурации
COPY docker/php/conf.d/xdebug.ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Переключаемся на пользователя www-data
USER www-data

# Запускаем PHP-FPM
CMD ["php-fpm"]

# Production stage
FROM base as production

# Копирование специальной production конфигурации PHP
COPY docker/php/conf.d/php-production.ini /usr/local/etc/php/conf.d/zzz-php-production.ini

# Копируем приложение
COPY --chown=www-data:www-data . .

# Устанавливаем зависимости без dev пакетов
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress \
    && php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

# Переключаемся на пользователя www-data
USER www-data

# Запускаем PHP-FPM
CMD ["php-fpm"]
