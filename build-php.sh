#!/bin/bash
# Build PHP-FPM Package

# Get the current script path
SCRIPTPATH=`pwd -P`
PCREVERSION=8.37
OPENSSLVERSION=1.0.2b
VERSION=$1
CORES=$(grep -c ^processor /proc/cpuinfo)
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

# Download and Extract the ARchive
wget http://us1.php.net/get/php-$VERSION.tar.gz/from/this/mirror -O php-$VERSION.tar.gz
tar -xf php-$VERSION.tar.gz

cd $SCRIPTPATH

# Copy Script Files
echo "Copying init.d and checkinstall file"
cp init-php-fpm /etc/init.d/php-fpm
cp init-php-fpm /tmp/php-$VERSION/init-php-fpm
cp setup /tmp/php-$VERSION/setup

cd /tmp/php-$VERSION

cd /tmp
wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$PCREVERSION.tar.gz
tar -xf pcre-$PCREVERSION.tar.gz
cd pcre-$PCREVERSION
./configure --enable-utf
make -j$CORES
cp pcre.h .libs/

# Install the latest version of OpenSSL rather than using the libaries provided with the host OS
#cd /tmp/php-$VERSION
#wget https://www.openssl.org/source/openssl-$OPENSSLVERSION.tar.gz
#tar -xf openssl-$OPENSSLVERSION.tar.gz

# Apply Cloudflare Chacha20-Poly1305 patch to OpenSSL
#cd openssl-$OPENSSLVERSION
#git clone https://github.com/cloudflare/sslconfig
#cp sslconfig/patches/openssl__chacha20_poly1305_cf.patch .
#patch -p1 < openssl__chacha20_poly1305_cf.patch

#./config --prefix=/tmp/php\-$VERSION/openssl\-$OPENSSLVERSION/.openssl shared enable-ec_nistp_64_gcc_128 enable-tlsext
#make depend
#make -j$CORES
#make install
#cd .openssl
#ln -s lib lib64

# Copy the Script Paths
cd /tmp/php-$VERSION
cp $SCRIPTPATH/*-pak .

./configure \
	--with-libdir=lib64 \
	--with-config-file-path=/etc/php \
	--with-config-file-scan-dir=/etc/php/conf.d \
	--with-pic \
	--without-gdbm \
	--with-gettext \
	--with-iconv \
	--with-openssl \
    --with-pcre-regex=/tmp/pcre-$PCREVERSION/.libs \
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
	--with-mysql \
	--with-gd \
	--with-mcrypt \
	--enable-pdo \
	--with-pdo-mysql=mysqlnd \
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
	--with-mysqli=mysqlnd \
	--with-sqlite3 \
	--with-readline \
	--enable-opcache \
	--enable-soap \
	--with-jpeg-dir \
	--with-png-dir \
	--enable-bcmath \
	--disable-short-tags \
	--enable-intl

	# --with-openssl=/tmp/php-$VERSION/openssl-$OPENSSLVERSION/.openssl \

# Install the init script
$(which update-rc.d) /etc/init.d/php-fpm defaults

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
	-requires "libxml2, libmcrypt4, libjpeg-turbo8" \
	-replaces "php-fpm-5.5" \
	-conflicts "php5, php5-common" \
	-pakdir /tmp \
	-y \
	sh /tmp/php-$VERSION/setup
