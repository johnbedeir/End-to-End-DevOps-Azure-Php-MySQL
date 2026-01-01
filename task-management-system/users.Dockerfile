# Use the official PHP image as the base image
FROM php:8.2-apache

# use root user
USER root 

# Set the working directory to /var/www/html
WORKDIR /var/www/html

# Copy the application files into the container
COPY css /var/www/html/css/
COPY js /var/www/html/js/
COPY includes /var/www/html/includes/
COPY pages/login.php /var/www/html/pages/
COPY pages/register.php /var/www/html/pages/
COPY pages/dashboard.php /var/www/html/pages/
COPY pages/add_task.php /var/www/html/pages/
COPY pages/delete_task.php /var/www/html/pages/
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
    gnupg \
    ca-certificates \
    && curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-prod.gpg \
    && echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql18 unixodbc-dev \
    && pecl install sqlsrv pdo_sqlsrv \
    && docker-php-ext-enable sqlsrv pdo_sqlsrv \
    && docker-php-ext-configure gd \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install zip \
    && docker-php-source delete

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN a2enmod rewrite

RUN composer install --no-dev --optimize-autoloader

RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Ensure Apache config allows .htaccess
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf \
    && sed -i '/<Directory \/var\/www\/html>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf \
    || echo -e "\n<Directory /var/www/html>\n    Options Indexes FollowSymLinks\n    AllowOverride All\n    Require all granted\n</Directory>" >> /etc/apache2/apache2.conf

# Set correct permissions for all files and directories
RUN chown -R www-data:www-data /var/www/html \
    && chmod 644 /var/www/html/.htaccess \
    && chmod 755 /var/www/html

# Expose port for Apache
EXPOSE 80

# Start Apache in the foreground
CMD ["apache2-foreground"]