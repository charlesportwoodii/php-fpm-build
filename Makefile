SHELL := /bin/bash

# Dependency Versions
PCREVERSION?=8.39
OPENSSLVERSION?=1.0.2i
CURLVERSION?=7_50_2
NGHTTPVERSION?=v1.14.0
RELEASEVER?=1

# Argon2 reference library implementation
ARGON2_DIR=/tmp/libargon2

# Bash data
SCRIPTPATH=$(shell pwd -P)
CORES=$(shell grep -c ^processor /proc/cpuinfo)

major=$(shell echo $(VERSION) | cut -d. -f1)
minor=$(shell echo $(VERSION) | cut -d. -f2)
micro=$(shell echo $(VERSION) | cut -d. -f3)

# Prefixes and constants
OPENSSL_PATH=/opt/openssl
NGHTTP_PREFIX=/opt/nghttp2
CURL_PREFIX=/opt/curl

# Ubuntu dependencies
ifeq ($(shell lsb_release --codename | cut -f2),trusty)
LIBICU=libicu52
else ifeq ($(shell lsb_release --codename | cut -f2),xenial)
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
 
build: openssl curl php

openssl:
	echo $(OPENSSL_PATH)
	rm -rf /tmp/openssl*
	cd /tmp && \
	wget https://www.openssl.org/source/openssl-$(OPENSSLVERSION).tar.gz && \
	tar -xf openssl-$(OPENSSLVERSION).tar.gz && \
	cd openssl-$(OPENSSLVERSION) && \
	git clone https://github.com/cloudflare/sslconfig && \
	cp sslconfig/patches/openssl__chacha20_poly1305_draft_and_rfc_ossl102g.patch . && \
	patch -p1 < openssl__chacha20_poly1305_draft_and_rfc_ossl102g.patch 2>/dev/null; true && \
	wget https://gist.githubusercontent.com/charlesportwoodii/9e95c6a4ecde31ea23c17f6823bdb320/raw/a02fac917fc30f4767fb60a9563bad69dc1c054d/chacha.patch && \
	patch < chacha.patch 2>/dev/null; true && \
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
	LIBS="-ldl" env PKG_CONFIG_PATH=$(OPENSSL_PATH)/lib/pkgconfig ./configure --prefix=$(NGHTTP_PREFIX) --enable-static=yes --enable-shared=no&& \
	make -j$(CORES) && \
	make install && \
	cd $(NGHTTP_PREFIX) && \
	ln -fs lib lib64

curl: nghttp2
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
		--with-nghttp2=$(NGHTTP_PREFIX) \
		--disable-ldaps && \
	make -j$(CORES) && \
	make install && \
	cd $(CURL_PREFIX) &&\
	ln -fs lib lib64

libargon2:
ifeq ($(shell test $(minor) -ge 2; echo $?),0)
	rm -rf $(ARGON2_DIR)
	
	cd /tmp && \
	git clone https://github.com/P-H-C/phc-winner-argon2 libargon2 && \
	cd $(ARGON2_DIR) && \
	CFLAGS="-fPIC" make

	cd $(ARGON2_DIR) && \
	ln -s . lib && \
	ln -s . libs

	rm -rf $(ARGON2_DIR)/libargon2.so*
endif

php: libargon2
	rm -rf /tmp/php-$(VERSION)
	echo Building for PHP $(VERSION)

	cd /tmp && \
	git clone --depth 15 -b php-$(VERSION) https://github.com/php/php-src.git /tmp/php-$(VERSION)

	# Checkout PHP	
	cd /tmp/php-$(VERSION) && git checkout tags/php-$(VERSION)

ifeq ($(major),7)
	echo "Using php7::phpredis"
	cd /tmp/php-$(VERSION)/ext && git clone -b php7 https://github.com/phpredis/phpredis redis
else
	cd /tmp/php-$(VERSION)/ext && git clone -b 2.2.8  https://github.com/phpredis/phpredis redis
endif

	# Build
	cd /tmp/php-$(VERSION) && \
	./buildconf  --force && \
	./configure CFLAGS="-I$(NGHTTP_PREFIX)/include" LDFLAGS="-L$(NGHTTP_PREFIX)/lib" \
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
		--with-password-argon2=$(ARGON2_DIR) \
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
	make -j$(CORES)

pre_package:
	# Removing the work build directory
	rm -rf /tmp/php-$(VERSION)-install

	# Install PHP FPM  to php-<version>-install for fpm
	cd /tmp/php-$(VERSION) && \
	make install INSTALL_ROOT=/tmp/php-$(VERSION)-install

	mkdir -p /tmp/php-$(VERSION)-install/usr/local/etc/php/conf.d
	mkdir -p /tmp/php-$(VERSION)-install/usr/local/etc/php/php-fpm.d

	# Export the timezone as UTC
	echo "date.timezone=UTC" >> /tmp/php-$(VERSION)-install/usr/local/etc/php/conf.d/UTC-timezone.ini

	# Copy the FPM configuration
	cp $(SCRIPTPATH)/conf/php-fpm.conf /tmp/php-$(VERSION)-install/usr/local/etc/php/php-fpm.conf.default
	cp $(SCRIPTPATH)/conf/default.conf /tmp/php-$(VERSION)-install/usr/local/etc/php/php-fpm.d/pool.conf.default
	mkdir -p /tmp/php-$(VERSION)-install/lib/systemd/system
	cp $(SCRIPTPATH)/php-fpm.service /tmp/php-$(VERSION)-install/lib/systemd/system/php-fpm.service

	# Copy the PHP.ini configuration
	cp /tmp/php-$(VERSION)/php.ini* /tmp/php-$(VERSION)-install/usr/local/etc/php

	# Remove useless items in /usr/lib/etc
	rm -rf /tmp/php-$(VERSION)-install/usr/local/etc/php-fpm.conf.default

	# Copy the license file
	cp /tmp/php-$(VERSION)/LICENSE /tmp/php-$(VERSION)-install/usr/local/etc/php/
	
	rm -rf /tmp/php-$(VERSION)-install/.registry
	rm -rf /tmp/php-$(VERSION)-install/.channels

fpm_debian: pre_package
	echo "Building native package for debian"

	# Copy init.d for non systemd systems
	mkdir -p /tmp/php-$(VERSION)-install/usr/local/etc/init.d
	cp $(SCRIPTPATH)/debian/init-php-fpm /tmp/php-$(VERSION)-install/usr/local/etc/init.d/php-fpm	

	fpm -s dir \
		-t deb \
		-n $(RELEASENAME) \
		-v $(VERSION)-$(RELEASEVER)~$(shell lsb_release --codename | cut -f2) \
		-C /tmp/php-$(VERSION)-install \
		-p $(RELEASENAME).$(micro)_$(RELEASEVER)~$(shell lsb_release --codename | cut -f2)_$(shell uname -m).deb \
		-m "charlesportwoodii@erianna.com" \
		--license "PHP License" \
		--url https://github.com/charlesportwoodii/php-fpm-build \
		--description "PHP FPM, $(VERSION)" \
		--vendor "Charles R. Portwood II" \
		--depends "libxml2 > 0" \
		--depends "libmcrypt4 > 0" \
		--depends "libjpeg-turbo8 > 0" \
		--depends "$(LIBICU) > 0" \
		--depends "libpq5 > 0" \
		--deb-systemd-restart-after-upgrade \
		--template-scripts \
		--force \
		--no-deb-auto-config-files \
		--before-install $(SCRIPTPATH)/debian/preinstall-pak \
		--after-install $(SCRIPTPATH)/debian/postinstall-pak \
		--before-remove $(SCRIPTPATH)/debian/preremove-pak 
		
fpm_rpm: pre_package
	echo "Building native package for rpm"

	fpm -s dir \
		-t rpm \
		-n $(RELEASENAME) \
		-v $(VERSION)_$(RELEASEVER) \
		-C /tmp/php-$(VERSION)-install \
		-p php-fpm-$(VERSION)_$(RELEASEVER).$(shell arch).rpm \
		-m "charlesportwoodii@erianna.com" \
		--license "PHP License" \
		--url https://github.com/charlesportwoodii/php-fpm-build \
		--description "PHP FPM, $(VERSION)" \
		--vendor "Charles R. Portwood II" \
		--depends "libxml2 > 0" \
		--depends "libmcrypt > 0" \
		--depends "libjpeg-turbo > 0" \
		--depends "libicu > 0" \
		--depends "postgresql-devel > 0" \
		--depends "libpng12 > 0" \
		--rpm-digest sha384 \
		--rpm-compression gzip \
		--template-scripts \
		--force \
		--before-install $(SCRIPTPATH)/rpm/preinstall \
		--after-install $(SCRIPTPATH)/rpm/postinstall \
		--before-remove $(SCRIPTPATH)/rpm/preremove 
