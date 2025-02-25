#################################
# stage builder: build and test
#################################
FROM php:7-apache-buster AS builder

RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -

RUN apt-get update > /dev/null
RUN apt-get install -y git libzip-dev nodejs python2 libgtk2.0-0 libgtk-3-0 libgbm-dev libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 libxtst6 xauth xvfb vim

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN docker-php-ext-install zip
RUN docker-php-ext-enable zip

RUN git clone https://github.com/Veles/filegator.git /var/www/filegator/
WORKDIR "/var/www/filegator/"
COPY configuration.php  /var/www/filegator/configuration.php

RUN composer install
RUN composer require league/flysystem-sftp:^1.0 -W
RUN npm install
RUN npm run build
RUN vendor/bin/phpunit
RUN npm run lint
#RUN npm run e2e
RUN rm -rf node_modules frontend tests docs .git .github
RUN rm README.md couscous.yml repository/.gitignore babel.config.js cypress* .env* .eslint* .gitignore jest.* .php_cs* phpunit* postcss* vue*

#################################
# stage production
#################################
FROM php:7-apache-buster

RUN apt-get update > /dev/null
RUN apt-get install -y git libzip-dev libldap2-dev

RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/
RUN docker-php-ext-install zip ldap
RUN docker-php-ext-enable zip ldap

COPY --from=builder /var/www/filegator /var/www/filegator
RUN chown -R www-data:www-data /var/www/filegator/
WORKDIR "/var/www/filegator/"
RUN chmod -R g+w private/
RUN chmod -R g+w repository/

ENV APACHE_DOCUMENT_ROOT=/var/www/filegator/dist/
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
RUN a2enmod rewrite

EXPOSE 80

VOLUME /var/www/filegator/repository
VOLUME /var/www/filegator/private

USER www-data

CMD ["apache2-foreground"]
