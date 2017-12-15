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

# Create /temp_dir for using
RUN mkdir /temp_docker && chmod -R +x /temp_docker && cd /temp_docker

# Install base php libs
RUN apt-get update && apt-get install -y --force-yes \
    php7.1-fpm php7.1-dev php7-openssl \
    php7.1-common php7.1-ftp php7.1-gd \
    php7.1-sockets php7.1-cgi \
    php7.1-zlib php7.1-bz2 php-pear php7.1-cli \
    php7.1-exif php7.1-phar php7.1-zip php7.1-calendar \
    php7.1-iconv php7.1-imap hp7.1-soap \
    php-mbstring php7.1-bcmath \
    php7.1-mcrypt php-curl php7.1-json \
    php7.1-opcache php7.1-ctype php7.1-xml \
    php7.1-xsl php7.1-ldap php7.1-xmlwriter php7.1-xmlreader \
    php-intl php7.1-tokenizer php7.1-session  \
    php7.1-pcntl php7.1-posix php7.1-apcu php7.1-simplexml \
    php7.1-pdo \
    php7.1-mysqlnd php7.1-pdo_mysql php7.1-mysqli \
    php7.1-pgsql php7.1-pdo_pgsql php7.1-gmp \
    php7.1-imagick php7.1-xmlrpc php7.1-dba \
    php7.1-odbc php7.1-pspell \
    php7.1-amqp php7.1-yaml php7.1-oauth \
    php7.1-readline php7.1-geoip php7.1-recode

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php -r "if (hash_file('SHA384', 'composer-setup.php') === '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv /composer.phar /usr/bin/composer && sudo chmod +x /usr/bin/composer

RUN apt install -y python-pip && pip install awscli

RUN pecl install xdebug

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

# Install MongoDB PHP extension
RUN sed -ie 's/-n//g' /usr/bin/pecl && \
    yes | pecl install mongodb && \
    echo 'extension=mongodb.so' > /etc/php7/conf.d/mongodb.ini && \
    rm -rf /tmp/pear

# Install xdebug
RUN cd /temp_docker && wget https://xdebug.org/files/xdebug-$XDEBUG_VERSION.tgz
RUN cd /temp_docker && tar -xvzf xdebug-$XDEBUG_VERSION.tgz
RUN cd /temp_docker && cd xdebug-$XDEBUG_VERSION && phpize
RUN cd /temp_docker && cd xdebug-$XDEBUG_VERSION && ./configure
RUN cd /temp_docker && cd xdebug-$XDEBUG_VERSION && make
RUN cd /temp_docker && cd xdebug-$XDEBUG_VERSION && make test
RUN cd /temp_docker && cd xdebug-$XDEBUG_VERSION && echo ";zend_extension = xdebug.so" > /etc/php7/conf.d/xdebug.ini
RUN cp /temp_docker/xdebug-$XDEBUG_VERSION/modules/xdebug.so /usr/lib/php7/modules/xdebug.so

RUN sed -i \
    -e "$ a xdebug.default_enable = 0" \
    -e "$ a xdebug.remote_enable = 1" \
    -e "$ a xdebug.remote_handler = dbgp" \
    -e "$ a xdebug.remote_port = 9000" \
    -e "$ a xdebug.remote_autostart = 1" \
    -e "$ a xdebug.remote_connect_back = 1" \
    -e "$ a xdebug.max_nesting_level = 256" \
/etc/php7/conf.d/xdebug.ini

# Install memcached
RUN cd /temp_docker && git clone https://github.com/php-memcached-dev/php-memcached && \
    cd php-memcached && git checkout php7 && git pull && \
    phpize && \
    ./configure --with-libmemcached-dir=no --disable-memcached-sasl && \
    make && \
    make install && \
    echo 'extension=memcached.so' > /etc/php7/conf.d/memcached.ini

# Install php-redis
RUN cd /temp_docker && git clone https://github.com/phpredis/phpredis.git && cd phpredis && \
    git checkout php7-ipv6 && git pull && \
    phpize  && \
    ./configure  && \
    make && \
    make install && \
echo 'extension=redis.so' > /etc/php7/conf.d/redis.ini

RUN apt-get update && apt-get upgrade --force-yes -y

RUN mkdir -p /var/www/html

RUN rm -f /etc/php/7.1/fpm/pool.d/*
COPY conf/pool.d/www.conf /etc/php/7.1/fpm/pool.d/www.conf
COPY conf/pool.d/zz-docker.conf /etc/php/7.1/fpm/pool.d/zz-docker.conf
COPY conf/php-fpm.conf /etc/php/7.1/fpm/php-fpm.conf
COPY conf/php.ini /etc/php/7.1/fpm/php.ini
COPY conf/cli.ini /etc/php/7.1/cli/php.ini

RUN service php7.1-fpm start

EXPOSE 9000
CMD ["php-fpm7.1", "--nodaemonize", "--force-stderr"]
