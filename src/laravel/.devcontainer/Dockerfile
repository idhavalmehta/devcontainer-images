ARG VARIANT=8.3-cli
FROM php:${VARIANT}

# Install Laravel dependencies
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
    @composer \
    pcntl \
    xdebug \
    intl \
    zip \
    dom \
    fileinfo \
    filter \
    libxml \
    xmlreader \
    pdo_mysql \
    mysqli \
    pdo_pgsql \
    pgsql \
    pdo_sqlsrv \
    sqlsrv

# Install Laravel installer globally
RUN export COMPOSER_HOME=/usr/local/composer \
    && composer global require laravel/installer \
    && ln -s /usr/local/composer/vendor/bin/laravel /usr/local/bin/laravel

# [Optional] Uncomment this section to install additional packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>