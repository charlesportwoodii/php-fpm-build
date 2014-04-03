#!/bin/bash
# Build PHP-FPM Package

# Get the current script path
SCRIPTPATH=`pwd -P`

VERSION=$1

# Build the package in tmp
rm -rf /tmp/php*
cd /tmp

# Download and Extract the ARchive
wget http://us1.php.net/get/php-$VERSION.tar.gz/from/this/mirror -O php-$VERSION.tar.gz
tar -xf php-$VERSION.tar.gz

# Copy the Script Paths
cd /tmp/php-$VERSION
cp $SCRIPTPATH/*-pak .

./configure  '--with-libdir=lib64' '--with-config-file-path=/etc/php' '--with-config-file-scan-dir=/etc/php/conf.d' '--with-pic' '--without-gdbm' '--with-gettext' '--with-iconv' '--with-openssl' '--with-zlib' '--with-layout=GNU' '--enable-exif' '--enable-ftp' '--enable-sockets' '--enable-sysvsem' '--enable-sysvshm' '--enable-sysvmsg' '--with-kerberos' '--enable-shmop' '--enable-calendar' '--with-mysql' '--with-gd' '--with-mcrypt' '--enable-pdo' '--with-pdo-mysql=mysqlnd' '--enable-json' '--with-curl' '--enable-fpm' '--enable-mbstring' '--enable-inline-optimization' '--enable-pcntl' '--enable-mbregex' '--with-mhash' '--with-pcre-regex' '--with-fpm-user=www-data' '--enable-zip' '--with-mysqli=mysqlnd' '--with-sqlite3' '--with-readline' '--enable-opcache' '--enable-soap' '--with-jpeg-dir' '--with-png-dir'

# Install the init script
cp /tmp/php-$VERSION/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
update-rc.d /etc/init.d/php-fpm defaults

mkdir -p /etc/php/conf.d
cp setup /tmp/php-$VERSION/setup
make -j2
make install
