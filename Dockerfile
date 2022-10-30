FROM php:8.1-fpm

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    acl \
    sudo \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libffi-dev \
    libbz2-dev \
    libssl-dev \
    libicu-dev \
    libonig-dev \
    libzip-dev \
    libedit-dev \
    libmemcached-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    mysqli \
    pdo_mysql \
    opcache \
    bcmath \
    bz2 \
    gd \
    calendar \
    exif \
    ffi \
    gettext \
    intl \
    shmop \
    sockets \
    sysvmsg \
    sysvsem \
    sysvshm \
    zip \
    pcntl \
    # Install igbinary (for more efficient serialization in redis/memcached)
    && for i in $(seq 1 3); do pecl install -o igbinary && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && docker-php-ext-enable igbinary \
    \
    # Install redis (manualy build in order to be able to enable igbinary)
    && for i in $(seq 1 3); do pecl install -o --nobuild redis && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/redis" \
    && phpize \
    && ./configure --enable-redis-igbinary \
    && make \
    && make install \
    && docker-php-ext-enable redis \
    && cd - \
    \
    # Install memcached (manualy build in order to be able to enable igbinary)
    && for i in $(seq 1 3); do echo no | pecl install -o --nobuild memcached && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/memcached" \
    && phpize \
    && ./configure --enable-memcached-igbinary \
    && make \
    && make install \
    && docker-php-ext-enable memcached \
    && cd - \
    \
    # Delete source & builds deps so it does not hang around in layers taking up space
    && pecl clear-cache \
    && rm -Rf "$(pecl config-get temp_dir)/*" \
    && docker-php-source delete \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $buildDeps

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Bishkek /etc/localtime && dpkg-reconfigure -f noninteractive tzdata

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN composer install
RUN rm -rf /var/cache/apk/*
RUN usermod -u 1000 www-data
WORKDIR /var/www/html
VOLUME /var/www/html

EXPOSE 9000
CMD [ "php-fpm" ]