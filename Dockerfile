FROM ubuntu:trusty

MAINTAINER pifagor87<pifagor87@gmail.com>

# Set the env variable DEBIAN_FRONTEND to noninteractive
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-utils gcc libsasl2-dev lib32z1-dev libldap2-dev libssl-dev openssl \
    python-software-properties software-properties-common build-essential \
    apt-transport-https git python libglib2.0-dev \
    curl wget git zip unzip libcurl3-openssl-dev

RUN add-apt-repository ppa:pinepain/libv8-5.2 -y && \
    add-apt-repository ppa:ondrej/php -y

RUN apt-get update && apt-get install -y --force-yes \
    php7.2-fpm php7.2-dev \
    php7.2-common php7.2-ftp php7.2-gd \
    php7.2-sockets php7.2-cgi \
    php7.2-bz2 php-pear php7.2-cli \
    php7.2-exif php7.2-phar php7.2-zip php7.2-calendar \
    php7.2-iconv php7.2-imap hp7.2-soap \
    php-mbstring php7.2-bcmath \
    php7.2-mcrypt php-curl php7.2-json \
    php7.2-opcache php7.2-ctype php7.2-xml \
    php7.2-xsl php7.2-ldap php7.2-xmlwriter php7.2-xmlreader \
    php-intl php7.2-tokenizer php7.2-pdo \
    php7.2-posix php7.2-apcu php7.2-simplexml \
    php7.2-mysqlnd php7.2-mysqli \
    php7.2-pgsql php7.2-gmp libsodium-dev \
    php7.2-imagick php7.2-xmlrpc php7.2-dba \
    php7.2-odbc php7.2-pspell libmemcached-dev \
    php7.2-amqp php7.2-yaml php7.2-oauth \
    php7.2-readline php7.2-geoip php7.2-recode php-xdebug

# Install libsodium
RUN cd /tmp && \
    git clone -b stable https://github.com/jedisct1/libsodium.git \
    && cd libsodium && ./configure && make check && make install
RUN pecl install -f libsodium
RUN echo 'extension=libsodium.so' >> /etc/php/7.2/fpm/conf.d/libsodium.ini
RUN echo 'extension=libsodium.so' >> /etc/php/7.2/cli/conf.d/libsodium.ini

RUN phpenmod pdo_mysql && phpenmod pdo_pgsql && phpenmod session \
    phpenmod zlib && phpenmod pcntl && phpenmod openssl && phpenmod libsodium

RUN pecl install mongodb-1.2.2
RUN echo "extension=mongodb.so" >> /etc/php/7.2/fpm/conf.d/30-mongodb.ini
RUN echo "extension=mongodb.so" >> /etc/php/7.2/cli/conf.d/30-mongodb.ini

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php -r "if (hash_file('SHA384', 'composer-setup.php') === '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv /composer.phar /usr/bin/composer && sudo chmod +x /usr/bin/composer

RUN composer require paragonie/halite:^v4

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
xdebug.profiler_enable_trigger=on' >> /etc/php/7.2/fpm/conf.d/20-xdebug.ini && \
    rm /etc/php/7.2/cli/conf.d/20-xdebug.ini && \
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
RUN echo 'extension=memcached.so' >> /etc/php/7.2/fpm/conf.d/memcached.ini
RUN echo 'extension=memcached.so' >> /etc/php/7.2/cli/conf.d/memcached.ini

# Install php-redis
RUN cd /temp_docker && git clone https://github.com/phpredis/phpredis.git && cd phpredis && \
    git checkout php7-ipv6 && git pull && \
    phpize  && ./configure  && make && make install
RUN echo 'extension=redis.so' >> /etc/php/7.2/fpm/conf.d/redis.ini
RUN echo 'extension=redis.so' >> /etc/php/7.2/cli/conf.d/redis.ini

RUN apt-get update && apt-get upgrade --force-yes -y

RUN mkdir -p /var/www/html

RUN rm -f /etc/php/7.2/fpm/pool.d/*
COPY conf/pool.d/www.conf /etc/php/7.2/fpm/pool.d/www.conf
COPY conf/pool.d/zz-docker.conf /etc/php/7.2/fpm/pool.d/zz-docker.conf
COPY conf/php-fpm.conf /etc/php/7.2/fpm/php-fpm.conf
COPY conf/php.ini /etc/php/7.2/fpm/php.ini
COPY conf/cli.ini /etc/php/7.2/cli/php.ini

RUN service php7.2-fpm start

EXPOSE 9000
CMD ["php-fpm7.2", "--nodaemonize", "--force-stderr"]
