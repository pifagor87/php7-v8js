FROM ubuntu:trusty

MAINTAINER pifagor87<pifagor87@gmail.com>

# Set the env variable DEBIAN_FRONTEND to noninteractive
ENV DEBIAN_FRONTEND noninteractive

# Drush version
ENV DRUSH_VERSION 8.x

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-utils gcc libsasl2-dev lib32z1-dev libldap2-dev libssl-dev openssl \
    python-software-properties software-properties-common build-essential \
    apt-transport-https git python libglib2.0-dev \
    curl wget git zip unzip libcurl3-openssl-dev

RUN add-apt-repository ppa:pinepain/libv8-archived -y && \
    add-apt-repository ppa:ondrej/php -y

RUN apt-get update && apt-get install -y --force-yes \
    php7.1-fpm php7.1-dev \
    php7.1-common php7.1-ftp php7.1-gd \
    php7.1-sockets php7.1-cgi \
    php7.1-bz2 php-pear php7.1-cli \
    php7.1-exif php7.1-phar php7.1-zip php7.1-calendar \
    php7.1-iconv php7.1-imap hp7.1-soap \
    php7.1-mbstring php7.1-bcmath \
    php7.1-mcrypt php7.1-curl php7.1-json \
    php7.1-opcache php7.1-ctype php7.1-xml \
    php7.1-xsl php7.1-ldap php7.1-xmlwriter php7.1-xmlreader \
    php7.1-intl php7.1-tokenizer php7.1-pdo \
    php7.1-posix php7.1-apcu php7.1-simplexml \
    php7.1-mysqlnd php7.1-mysqli \
    php7.1-pgsql php7.1-gmp \
    php7.1-imagick php7.1-xmlrpc php7.1-dba \
    php7.1-odbc php7.1-pspell libmemcached-dev \
    php7.1-amqp php7.1-yaml php7.1-oauth \
    php7.1-readline php7.1-geoip php7.1-recode php-xdebug

RUN phpenmod pdo_mysql && phpenmod pdo_pgsql && phpenmod session \
    phpenmod zlib && phpenmod pcntl && phpenmod openssl

RUN pecl install mongodb-1.2.2
RUN echo "extension=mongodb.so" >> /etc/php/7.1/fpm/conf.d/30-mongodb.ini
RUN echo "extension=mongodb.so" >> /etc/php/7.1/cli/conf.d/30-mongodb.ini

# Create /temp_dir for using
RUN mkdir /temp_docker && chmod -R +x /temp_docker
# Add setup drush and composer script
COPY setup_extensions/composer_drush.sh /temp_docker/composer_drush.sh
RUN chmod -R +x /temp_docker && cd /temp_docker && bash /temp_docker/composer_drush.sh $DRUSH_VERSION
# Clean trash
RUN cd .. && rm -rf /temp_docker

RUN apt install -y python-pip && pip install awscli

RUN apt-get install libv8-5.2

RUN cd /tmp && \
    git clone https://github.com/phpv8/v8js.git && \
    cd v8js && \
    phpize && \
    ./configure --with-v8js=/opt/v8 && \
    make && \
    make test && \
    make install

RUN curl -sL https://deb.nodesource.com/setup_8.x | sudo bash - && \
    apt install -y nodejs && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install yarn && \
    yarn global add gulp-cli && \
    yarn global add webpack

RUN echo 'xdebug.remote_enable=1\n\
xdebug.remote_autostart=1\n\
xdebug.remote_port=9000\n\
xdebug.default_enable = 0\n\
xdebug.remote_handler = dbgp\n\
xdebug.remote_connect_back = 1\n\
xdebug.max_nesting_level = 256\n\
xdebug.profiler_output_dir=/var/www/var/profiler\n\
xdebug.profiler_enable_trigger=on' >> /etc/php/7.1/fpm/conf.d/20-xdebug.ini && \
    rm /etc/php/7.1/cli/conf.d/20-xdebug.ini && \
    apt-get remove -y curl && \
    apt-get clean && \
    apt-get purge && \
    mkdir /run/php
RUN mkdir /temp_docker && chmod -R +x /temp_docker && cd /temp_docker

# Install memcached
RUN cd /temp_docker && git clone https://github.com/php-memcached-dev/php-memcached && \
    cd php-memcached && git checkout php7 && git pull && \
    phpize && \
    ./configure --with-libmemcached-dir=no --disable-memcached-sasl && \
    make && make install
RUN echo 'extension=memcached.so' >> /etc/php/7.1/fpm/conf.d/memcached.ini
RUN echo 'extension=memcached.so' >> /etc/php/7.1/cli/conf.d/memcached.ini

# Install php-redis
RUN cd /temp_docker && git clone https://github.com/phpredis/phpredis.git && cd phpredis && \
    git checkout php7-ipv6 && git pull && \
    phpize  && ./configure  && make && make install
RUN echo 'extension=redis.so' >> /etc/php/7.1/fpm/conf.d/redis.ini
RUN echo 'extension=redis.so' >> /etc/php/7.1/cli/conf.d/redis.ini

RUN apt-get update && apt-get upgrade --force-yes -y

RUN mkdir -p /var/www/html

# Clean trash
RUN rm -rf /temp_docker
RUN rm -f /etc/php/7.1/fpm/pool.d/*
COPY conf/pool.d/www.conf /etc/php/7.1/fpm/pool.d/www.conf
COPY conf/pool.d/zz-docker.conf /etc/php/7.1/fpm/pool.d/zz-docker.conf
COPY conf/php-fpm.conf /etc/php/7.1/fpm/php-fpm.conf
COPY conf/php.ini /etc/php/7.1/fpm/php.ini
COPY conf/cli.ini /etc/php/7.1/cli/php.ini

RUN service php7.1-fpm start

RUN echo 'PATH="$HOME/.composer/vendor/bin:$PATH"' >> ~/.bashrc
RUN /bin/bash -c "source ~/.bashrc"

EXPOSE 9000
CMD ["php-fpm7.1", "--nodaemonize", "--force-stderr"]
