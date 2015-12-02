#!/bin/bash
# Build PHP-FPM Package
# Get the current script path
SCRIPTPATH=`pwd -P`
PCREVERSION=8.37
OPENSSLVERSION=1.0.2d
VERSION=$1
CORES=$(grep -c ^processor /proc/cpuinfo)

# Get the OS libicu package for dependencies
for i in $(apt-cache search 'libicu' | awk '{print $1}')
do
    if [[ ! "$i" =~ "dev" ]] && [[ ! "$i" =~ "java" ]] && [[ ! "$i" =~ "dbg" ]]
    then
        LIBICU=$i
    fi
done

if [ -z "$2" ]
then
    RELEASEVER=1;
else
    RELEASEVER=$2;
fi
RELEASE=$(lsb_release --codename | cut -f2)

version=$(echo $VERSION | grep -o [^-]*$)
major=$(echo $version | cut -d. -f1)
minor=$(echo $version | cut -d. -f2)
micro=$(echo $version | cut -d. -f3)

RELEASENAME="php-fpm"

# Build the package in tmp
rm -rf /tmp/php*
cd /tmp

# Download from git
git clone --depth 1 -b php-$VERSION https://github.com/php/php-src.git /tmp/php-$VERSION
cd php-$VERSION
git checkout tags/php-$VERSION

# Install OpenSSL 1.0.2e to tmp path
wget https://www.openssl.org/source/openssl-$OPENSSLVERSION.tar.gz
tar -xf openssl-$OPENSSLVERSION.tar.gz

# Apply Cloudflare Chacha20-Poly1305 patch to OpenSSL
cd openssl-$OPENSSLVERSION
git clone https://github.com/cloudflare/sslconfig
cp sslconfig/patches/openssl__chacha20_poly1305_cf.patch .
patch -p1 < openssl__chacha20_poly1305_cf.patch

./config --prefix=/tmp/php\-$VERSION/openssl\-$OPENSSLVERSION/.openssl no-shared enable-ec_nistp_64_gcc_128 enable-tlsext
make depend
make -j$CORES
make install

# Symlink lib=>lib64 for PHP_LIB variable
cd /tmp/php\-$VERSION/openssl\-$OPENSSLVERSION/.openssl
ln -s lib lib64

cd $SCRIPTPATH

# Copy Script Files
echo "Copying init.d and checkinstall file"
cp init-php-fpm /etc/init.d/php-fpm
cp init-php-fpm /tmp/php-$VERSION/init-php-fpm
cp setup /tmp/php-$VERSION/setup

cd /tmp/php-$VERSION/ext

if [[ $VERSION == 7* ]]
then
	git clone -b php7 https://github.com/phpredis/phpredis redis
	PROVIDES="php-fpm-"$major
	REPLACES="php-fpm-5.5, php-fpm-5.6, php-fpm"
else
	git clone https://github.com/phpredis/phpredis redis
	PROVIDES="php-fpm, php-fpm-"$major"."$minor	
	REPLACES="php-fpm-5.5"
fi

# Copy the Script Paths
cd /tmp/php-$VERSION
cp -R $SCRIPTPATH/*-pak .

# Build conf for git
./buildconf  --force

./configure \
	--with-libdir=lib64 \
	--with-config-file-path=/etc/php \
	--with-config-file-scan-dir=/etc/php/conf.d \
	--with-pic \
	--without-gdbm \
	--with-gettext \
	--with-iconv \
	--with-openssl \
	--with-pcre-regex \
	--with-zlib \
	--with-layout=GNU \
	--enable-exif \
	--enable-ftp \
	--enable-sockets \
	--enable-sysvsem \
	--enable-sysvshm \
	--enable-sysvmsg \
	--with-kerberos \
	--enable-shmop \
	--enable-calendar \
	--with-gd \
	--with-mcrypt \
	--enable-pdo \
	--with-pdo-mysql=mysqlnd \
	--with-mysqli=mysqlnd \
	--with-mysql \
	--enable-json \
	--with-curl \
	--enable-fpm \
	--enable-mbstring \
	--enable-inline-optimization \
	--enable-pcntl \
	--enable-mbregex \
	--with-mhash \
	--with-fpm-user=www-data \
	--enable-zip \
	--with-sqlite3 \
	--with-readline \
	--enable-opcache \
	--enable-soap \
	--with-jpeg-dir \
	--with-freetype-dir \
	--with-png-dir \
	--enable-bcmath \
	--disable-short-tags \
	--enable-intl \
	--with-openssl=/tmp/php-$VERSION/openssl-$OPENSSLVERSION/.openssl \
	--enable-redis

# Install the init script
$(which update-rc.d) php-fpm defaults

mkdir -p /etc/php/conf.d
make -j$CORES
make install

cd /tmp/php-$VERSION
checkinstall \
	-D \
	--fstrans \
	-pkgrelease "$RELEASEVER"-"$RELEASE" \
	-pkgrelease "$RELEASEVER"~"$RELEASE" \
	-pkgname $RELEASENAME \
	-pkglicense PHP \
	-pkggroup PHP \
	-maintainer charlesportwoodii@ethreal.net \
	-provides "$PROVIDES" \
	-requires "libxml2, libmcrypt4, libjpeg-turbo8, $LIBICU" \
	-replaces "$REPLACES" \
	-conflicts "php5, php5-common" \
	-pakdir /tmp \
	-y \
	sh /tmp/php-$VERSION/setup
