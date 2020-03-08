FROM node:alpine as frontend

COPY package.json /app/

RUN cd /app \
      && npm install
#      && npm install --registry=https://registry.npm.taobao.org

COPY webpack.mix.js /app/
COPY resources/ /app/resources/

RUN cd /app \
      && npm run production

FROM composer as composer

COPY database/ /app/database/
COPY composer.json composer.lock /app/

RUN cd /app \
#      && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/ \
      && composer global require hirak/prestissimo \
      && composer install \
           --ignore-platform-reqs \
           --no-interaction \
           --no-plugins \
           --no-scripts \
           --prefer-dist

FROM laradock/php-fpm:latest-7.3 as php-fpm

ARG LARAVEL_PATH=/app/laravel

USER root

RUN set -xe; \
    apt-get update -yqq && \
    pecl channel-update pecl.php.net && \
    pecl install -o -f redis &&\
    apt-get install -yqq apt-utils libzip-dev zip unzip && \
    apt-get -y install inetutils-ping && \
    apt-get install -y zlib1g-dev libicu-dev g++ && \
    docker-php-ext-configure zip --with-libzip && \
    docker-php-ext-install zip && \
    docker-php-ext-install bcmath && \
    docker-php-ext-install opcache && \
    docker-php-ext-configure intl && \
    docker-php-ext-install intl && \
    docker-php-ext-enable redis &&\
    rm -rf /tmp/pear

ARG PUID=1000
ENV PUID ${PUID}
ARG PGID=1000
ENV PGID ${PGID}

RUN groupmod -o -g ${PGID} www-data && \
    usermod -o -u ${PUID} -g www-data www-data

COPY devops/php-fpm/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY devops/php-fpm/laravel.ini /usr/local/etc/php/conf.d
COPY devops/php-fpm/xlaravel.pool.conf /usr/local/etc/php-fpm.d/

COPY . ${LARAVEL_PATH}
COPY --from=composer /app/vendor/ ${LARAVEL_PATH}/vendor/
COPY --from=frontend /app/public/js/ ${LARAVEL_PATH}/public/js/
COPY --from=frontend /app/public/css/ ${LARAVEL_PATH}/public/css/
COPY --from=frontend /app/mix-manifest.json ${LARAVEL_PATH}/mix-manifest.json

# Clean up
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm /var/log/lastlog /var/log/faillog

RUN cd ${LARAVEL_PATH} \
      && copy .env.example .env
      && php artisan package:discover \
      && mkdir -p storage \
      && mkdir -p storage/framework/cache \
      && mkdir -p storage/framework/sessions \
      && mkdir -p storage/framework/testing \
      && mkdir -p storage/framework/views \
      && mkdir -p storage/logs \
      && chmod -R 777 storage
      && php artisan config:cache \
      && php artisan route:cache \

WORKDIR ${LARAVEL_PATH}

FROM nginx:alpine as nginx

ARG LARAVEL_PATH=/app/laravel

COPY devops/nginx/laravel.conf /etc/nginx/conf.d/
COPY --from=php-fpm ${LARAVEL_PATH}/public ${LARAVEL_PATH}/public