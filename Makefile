SHELL := /bin/bash

# Dependency Versions
PCREVERSION?=8.37
OPENSSLVERSION?=1.0.2f
CURLVERSION?=7_46_0
NGHTTPVERSION?=v1.5.0
RELEASEVER?=1

# Bash data
SCRIPTPATH=$(shell pwd -P)
CORES=$(shell grep -c ^processor /proc/cpuinfo)
RELEASE=$(shell lsb_release --codename | cut -f2)

major=$(shell echo $(VERSION) | cut -d. -f1)
minor=$(shell echo $(VERSION) | cut -d. -f2)
micro=$(shell echo $(VERSION) | cut -d. -f3)

# Prefixes and constants
OPENSSL_PATH=/opt/openssl
NGHTTP_PREFIX=/opt/nghttp2
CURL_PREFIX=/opt/curl

# checkinstall dependencies
ifeq ($(RELEASE),trusty)
LIBICU=libicu52
else ifeq ($(RELEASE),xenial)
LIBICU=libicu55
else
LIBICU=libicu48
endif

ifeq ($(major), 7)
RELEASENAME=php-fpm-$(major).$(minor)
REPLACES=php-fpm, php-fpm-5.5, php-fpm-5.6
PROVIDES=php-fpm-$(major).$(minor)	
CONFLICTS=php$(major), php$(major)-common, php-fpm, php-fpm-5.6
else
RELEASENAME=php-fpm
REPLACES=php-fpm-5.5
PROVIDES=php-fpm, php-fpm-$(major).$(minor)
CONFLICTS=php$(major), php$(major)-common
endif
 
build: openssl nghttp2 curl php

openssl:
	echo $(OPENSSL_PATH)
	rm -rf /tmp/openssl*
	cd /tmp && \
	wget https://www.openssl.org/source/openssl-$(OPENSSLVERSION).tar.gz && \
	tar -xf openssl-$(OPENSSLVERSION).tar.gz && \
	cd openssl-$(OPENSSLVERSION) && \
	git clone https://github.com/cloudflare/sslconfig && \
	cp sslconfig/patches/openssl__chacha20_poly1305_cf.patch . && \
	patch -p1 < openssl__chacha20_poly1305_cf.patch && \
	./config --prefix=$(OPENSSL_PATH) no-shared enable-ec_nistp_64_gcc_128 enable-tlsext no-ssl2 no-ssl3 && \
	make depend && \
	make -j$(CORES) && \
	make all && \
	make install_sw && \
	cd $(OPENSSL_PATH) && \
	ln -fs lib lib64

nghttp2:
	echo $(NGHTTP_PREFIX)
	rm -rf /tmp/nghttp2*
	cd /tmp && \
	git clone https://github.com/tatsuhiro-t/nghttp2 && \
	cd nghttp2 && \
	git checkout $(NGHTTPVERSION) &&\
	autoreconf -i && \
	automake && \
	autoconf && \
	LIBS="-ldl" env PKG_CONFIG_PATH=$(OPENSSL_PATH)/lib/pkgconfig ./configure --prefix=$(NGHTTP_PREFIX) && \
	make -j$(CORES) && \
	make install && \
	cd $(NGHTTP_PREFIX) && \
	ln -fs lib lib64

curl:
	echo $(CURL_PREFIX)
	rm -rf /tmp/curl*
	cd /tmp && \
	git clone https://github.com/bagder/curl && \
	cd curl &&\
	git checkout curl-$(CURLVERSION) &&\
	./buildconf && \
	autoreconf -fi && \
	LIBS="-ldl" env PKG_CONFIG_PATH=$(OPENSSL_PATH)/lib/pkgconfig \
	./configure  \
		--prefix=$(CURL_PREFIX) \
		--with-ssl \
		--disable-shared \
		--disable-ldap \
		--disable-ldaps && \
	make -j$(CORES) && \
	make install && \
	cd $(CURL_PREFIX) &&\
	ln -fs lib lib64

php:
	rm -rf /tmp/php-$(VERSION)
	echo Building for PHP $(VERSION)

	cd /tmp && \
	git clone --depth 1 -b php-$(VERSION) https://github.com/php/php-src.git /tmp/php-$(VERSION)

	# Checkout PHP	
	cd /tmp/php-$(VERSION) && git checkout tags/php-$(VERSION)

ifeq ($(major),7)
	echo "Using php7::phpredis"
	cd /tmp/php-$(VERSION)/ext && git clone -b php7 https://github.com/phpredis/phpredis redis
else
	cd /tmp/php-$(VERSION)/ext && git clone https://github.com/phpredis/phpredis redis
endif

	# Build
	cd /tmp/php-$(VERSION) && \
	./buildconf  --force && \
	./configure \
		--with-libdir=lib64 \
		--with-config-file-path=/etc/php \
		--with-config-file-scan-dir=/etc/php/conf.d \
		--with-pic \
		--without-gdbm \
		--with-gettext \
		--with-iconv \
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
		--with-curl=$(CURL_PREFIX) \
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
		--with-openssl=$(OPENSSL_PATH) \
		--with-pgsql \
		--with-pdo-pgsql \
		--enable-redis && \
	make -j$(CORES) && \
	make install

package:
	# Copy the fpm build packages
	cp $(SCRIPTPATH)/init-php-fpm /tmp/php-$(VERSION)/init-php-fpm
	cp $(SCRIPTPATH)/setup /tmp/php-$(VERSION)/setup
	cp -R $(SCRIPTPATH)/*-pak /tmp/php-$(VERSION)
	
	# Mk /etc/php/conf.d so checkinstall doesn't freak out
	mkdir -p /etc/php/conf.d
	
	# Copy the init.d script so checkinstall builds
	cp $(SCRIPTPATH)/init-php-fpm /etc/init.d/php-fpm

	cd /tmp/php-$(VERSION) && \
	checkinstall -D --fstrans -pkgrelease "$(RELEASEVER)~$(RELEASE)" -pkgname "$(RELEASENAME)" -pkglicense "PHP" -pkggroup "PHP" -maintainer "charlesportwoodii@ethreal.net" \
		-provides "$(PROVIDES)"	-requires "libxml2, libmcrypt4, libjpeg-turbo8, $(LIBICU), libpq5" -replaces "$(REPLACES)" -conflicts "$(CONFLICTS)" -pakdir "/tmp" -y sh /tmp/php-$(VERSION)/setup
