FROM node:alpine as frontend

COPY package.json /app/

RUN cd /app \
      && npm install

COPY webpack.mix.js /app/
COPY resources/ /app/resources/

RUN cd /app \
      && npm run production

FROM composer as composer

COPY database/ /app/database/
COPY composer.json composer.lock /app/

RUN cd /app \
      && composer global require hirak/prestissimo \
      && composer install \
           --ignore-platform-reqs \
           --no-interaction \
           --no-plugins \
           --no-scripts \
           --prefer-dist

FROM sakyavarro/php:7.3-fpm as php-fpm

ARG LARAVEL_PATH=/app/laravel

COPY . ${LARAVEL_PATH}
COPY --from=composer /app/vendor/ ${LARAVEL_PATH}/vendor/
COPY --from=frontend /app/public/js/ ${LARAVEL_PATH}/public/js/
COPY --from=frontend /app/public/css/ ${LARAVEL_PATH}/public/css/
COPY --from=frontend /app/mix-manifest.json ${LARAVEL_PATH}/mix-manifest.json

RUN cd ${LARAVEL_PATH} \
      && cp .env.example .env \
      && php artisan package:discover \
      && mkdir -p storage \
      && mkdir -p storage/framework/cache \
      && mkdir -p storage/framework/sessions \
      && mkdir -p storage/framework/testing \
      && mkdir -p storage/framework/views \
      && mkdir -p storage/logs \
      && chmod -R 777 storage \
      && php artisan config:cache \
      && php artisan route:cache

WORKDIR ${LARAVEL_PATH}

FROM nginx:alpine as nginx

ARG LARAVEL_PATH=/app/laravel

COPY devops/nginx/laravel.conf /etc/nginx/conf.d/
COPY --from=php-fpm ${LARAVEL_PATH}/public ${LARAVEL_PATH}/public