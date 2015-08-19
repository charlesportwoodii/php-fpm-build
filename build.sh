#!/bin/bash
# Build PHP-FPM Package
# Get the current script path
SCRIPTPATH=`pwd -P`
PCREVERSION=8.37
OPENSSLVERSION=1.0.1o
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

cd $SCRIPTPATH

# Copy Script Files
echo "Copying init.d and checkinstall file"
cp init-php-fpm /etc/init.d/php-fpm
cp init-php-fpm /tmp/php-$VERSION/init-php-fpm
cp setup /tmp/php-$VERSION/setup

cd /tmp/php-$VERSION/ext

if [[ $VERSION == 7* ]]
then
    echo "Adding PHP7 compatible phpredis package"
    git clone https://github.com/edtechd/phpredis redis
else
    echo "Adding phpredis package"
    git clone https://github.com/phpredis/phpredis redis
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
	--enable-redis # Statically compile PHPRedis 
	# --with-openssl=/tmp/php-$VERSION/openssl-$OPENSSLVERSION/.openssl \

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
	-provides "php-fpm, php-fpm-"$major"."$minor \
	-requires "libxml2, libmcrypt4, libjpeg-turbo8, $LIBICU" \
	-replaces "php-fpm-5.5" \
	-conflicts "php5, php5-common" \
	-pakdir /tmp \
	-y \
	sh /tmp/php-$VERSION/setup
