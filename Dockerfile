
FROM php:7.4-apache

RUN apt-get update && apt-get install --yes --force-yes wget unzip cron g++ gettext libicu-dev openssl \
    libc-client-dev libkrb5-dev libxml2-dev libfreetype6-dev libgd-dev libmcrypt-dev bzip2 libbz2-dev \
    libtidy-dev libcurl4-openssl-dev libz-dev libmemcached-dev libxslt-dev libwebp-dev

RUN a2enmod rewrite ssl

RUN docker-php-ext-install mysqli 
RUN docker-php-ext-enable mysqli

RUN docker-php-ext-configure gd --with-freetype=/usr --with-jpeg=/usr --with-webp
RUN docker-php-ext-install gd

# Download and install ionCube Loader
RUN wget https://downloads4.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.zip \
    && unzip ioncube_loaders_lin_x86-64.zip \
    && mv ioncube/ioncube_loader_lin_7.4.so $(php -r 'echo ini_get("extension_dir");') \
    && echo "zend_extension=$(php -r 'echo ini_get("extension_dir");')/ioncube_loader_lin_7.4.so" > /usr/local/etc/php/conf.d/00-ioncube.ini \
    && rm -rf ioncube ioncube_loaders_lin_x86-64.zip

# SoapClient
RUN apt-get install -y libxml2-dev
RUN docker-php-ext-install soap

# Install Redis extension
RUN pecl install redis \
    && docker-php-ext-enable redis

# Set the working directory
WORKDIR /var/www/html/

# Create a self-signed SSL certificate
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com"

# Configure Apache to use the SSL certificate
RUN echo "<VirtualHost *:443>\n\
    DocumentRoot /var/www/html\n\
    SSLEngine on\n\
    SSLCertificateFile /etc/ssl/certs/apache-selfsigned.crt\n\
    SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key\n\
    </VirtualHost>" > /etc/apache2/sites-available/default-ssl.conf

RUN a2ensite default-ssl

# Expose ports
EXPOSE 80 443

RUN chown -R www-data:www-data /var/www/html

# Start Apache
CMD mkdir -p /configs & \
    cp -n /usr/local/etc/php/php.ini-production /configs/php.ini & \
    cp /configs/php.ini /usr/local/etc/php/ & \
    apache2-foreground