# Multi-stage build for development and production
FROM php:8.4-fpm-alpine as base

# Install system dependencies (Alpine Linux)
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

# Install PHP extensions
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

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create user for security
RUN groupmod -g 1000 www-data \
    && usermod -u 1000 -g www-data www-data

# Copy configuration
COPY docker/php/conf.d/php.ini /usr/local/etc/php/php.ini

WORKDIR /var/www/html

# Development stage
FROM base as development

# Install Xdebug
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS linux-headers \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apk del .build-deps

# Copy Xdebug configuration
COPY docker/php/conf.d/xdebug.ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Switch to www-data user
USER www-data

# Start PHP-FPM
CMD ["php-fpm"]

# Production stage
FROM base as production

# Copy production PHP configuration
COPY docker/php/conf.d/php-production.ini /usr/local/etc/php/conf.d/zzz-php-production.ini

# Copy application
COPY --chown=www-data:www-data . .

# Install dependencies without dev packages
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress \
    && php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

# Switch to www-data user
USER www-data

# Start PHP-FPM
CMD ["php-fpm"]
