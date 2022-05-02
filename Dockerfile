FROM registry.access.redhat.com/ubi8/ubi

EXPOSE 8080
EXPOSE 8443

# switch to root user for installations
USER root

# enviornment variables
ENV PHP_VERSION=7.3 

# Install Apache httpd and PHP - all the packages from the PHP7.3 ubi + php-devel, php-pear, php-json and make
RUN yum -y module enable php:$PHP_VERSION && \
    INSTALL_PKGS="php php-mysqlnd php-pgsql php-bcmath php-devel php-json php-pear \
                  php-gd php-intl php-json php-ldap php-mbstring php-pdo \
                  php-process php-soap php-opcache php-xml \
                  php-gmp php-pecl-apcu php-pecl-zip mod_ssl hostname make" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    yum reinstall -y tzdata && \
    rpm -V $INSTALL_PKGS && \
    yum -y clean all --enablerepo='*'

# envorinment variables as copied form the PHP7.3 ubi
ENV PHP_CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/php/ \
    APP_DATA=${APP_ROOT}/src \
    PHP_DEFAULT_INCLUDE_PATH=/usr/share/pear \
    PHP_SYSCONF_PATH=/etc \
    PHP_HTTPD_CONF_FILE=php.conf \
    HTTPD_CONFIGURATION_PATH=${APP_ROOT}/etc/conf.d \
    HTTPD_MAIN_CONF_PATH=/etc/httpd/conf \
    HTTPD_MAIN_CONF_D_PATH=/etc/httpd/conf.d \
    HTTPD_MODULES_CONF_D_PATH=/etc/httpd/conf.modules.d \
    HTTPD_VAR_RUN=/var/run/httpd \
    HTTPD_DATA_PATH=/var/www \
    HTTPD_DATA_ORIG_PATH=/var/www \
    HTTPD_VAR_PATH=/var

# install zip, composer
RUN yum update && \
    yum install -y zip && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# install MongoDB PHP extension
RUN pecl install mongodb && echo "extension=mongodb.so" > /etc/php.ini

# Apache setup
COPY ./docker/apache-vhost-https.conf /etc/httpd/conf.d/000-default.conf
COPY ./docker/apache-vhost.conf /etc/httpd/conf.d/http.conf
RUN sed -i s=logs/ssl_error_log=/tmp/logpipe=g /etc/httpd/conf.d/ssl.conf
RUN sed -i s=logs/ssl_access_log=/tmp/logpipe=g /etc/httpd/conf.d/ssl.conf
RUN sed -i s=logs/ssl_request_log=/tmp/logpipe=g /etc/httpd/conf.d/ssl.conf
# change SSL port from 443 to 8443 so we can run apache as non-root
RUN sed -i s/443/8443/g /etc/httpd/conf.d/ssl.conf
RUN rm /etc/httpd/conf.modules.d/01-cgi.conf
COPY ./docker/httpd.conf /etc/httpd/conf/httpd.conf
RUN mkdir -p /etc/pki/tls/private/ /etc/pki/tls/certs

# run the composer
COPY . /var/www/html
WORKDIR /var/www/html
RUN composer install

# Laravel setup
RUN chmod go-w /var/www/html && \
    chmod u+w /var/www/html && \
    find /var/www -perm 0777 | xargs -r chmod 0755 && \
    find storage -name .gitignore | xargs -r chmod 0644 && \
    cp .env.example .env && \
    php artisan key:generate

# download mapping file
ADD https://raw.githubusercontent.com/sfu-ireceptor/config/turnkey-v4/AIRR-iReceptorMapping.txt /var/www/html/config/
RUN chmod 644 /var/www/html/config/AIRR-iReceptorMapping.txt

# change config and html directory ownership
# workaround for permission issue with /etc/httpd/run folder
RUN rm -rf /etc/httpd/run
RUN mkdir /etc/httpd/run

# set file permissions
RUN chgrp -R 0 /etc/pki && chmod -R g=u /etc/pki
RUN chgrp -R 0 /etc/httpd && chmod -R g=u /etc/httpd
RUN chgrp -R 0 /var/www/html && chmod -R g=u /var/www/html

# change to non-root user - just for cleaness, infact the openshift platform
# will run the docker as an arbitrary user beloning to the root group
WORKDIR /var/www/html
USER 1001

# run the apache server
CMD sh /var/www/html/docker/start_apache.sh
