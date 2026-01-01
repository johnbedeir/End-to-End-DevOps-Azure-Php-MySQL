# Use the official PHP image as the base image
FROM php:8.2-apache

# use root user
USER root 

# Set the working directory to /var/www/html
WORKDIR /var/www/html

# Copy the application files into the container
COPY css /var/www/html/css/
COPY js /var/www/html/js/
COPY index.php /var/www/html
COPY composer.json composer.lock* /var/www/html/
COPY .htaccess /var/www/html/.htaccess

RUN apt-get update && apt-get install -y\
    libpng-dev \
    zlib1g-dev \
    libxml2-dev \
    libzip-dev \ 
    zip \
    curl \
    unzip \
    && docker-php-ext-configure gd \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install zip \
    && docker-php-source delete

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN a2enmod rewrite

RUN composer install --no-dev --optimize-autoloader

# Ensure Apache config allows .htaccess
# The PHP Apache image has a default config, we need to update it
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf \
    && sed -i '/<Directory \/var\/www\/html>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf \
    || echo -e "\n<Directory /var/www/html>\n    Options Indexes FollowSymLinks\n    AllowOverride All\n    Require all granted\n</Directory>" >> /etc/apache2/apache2.conf

# Set correct permissions for all files including .htaccess
RUN chown -R www-data:www-data /var/www/html \
    && chmod 644 /var/www/html/.htaccess \
    && chmod 755 /var/www/html

# Expose port 80 for Apache
EXPOSE 80

# Start Apache in the foreground
CMD ["apache2-foreground"]