SHELL := /bin/bash

# Dependency Versions
PCREVERSION?=8.40
OPENSSLVERSION?=1.0.2l
CURLVERSION?=7_54_1
NGHTTPVERSION?=v1.14.0
RELEASEVER?=1

# Library versions
ARGON2VERSION?=20161029
LIBSODIUMVERSION?=stable

# External extension versions
REDISEXTVERSION?=3.1.2
ARGON2EXTVERSION?=1.2.1
LIBSODIUMEXTVERSION?=1.0.6

SHARED_EXTENSIONS := pdo_sqlite pdo_pgsql pdo_mysql json pgsql mysqlnd mysqli sqlite3 xml mbstring zip intl redis mcrypt xsl bz2 gd enchant ldap odbc pspell recode argon2 libsodium gmp
SHARED_ZEND_EXTENSIONS := opcache
REALIZED_EXTENSIONS := sqlite3 mysql pgsql xml mbstring zip intl redis mcrypt xsl bz2 gd enchant ldap odbc pspell recode argon2 libsodium gmp

# Reference library implementations
ARGON2_DIR=/tmp/libargon2
LIBSODIUM_DIR=/tmp/libsodium

# Current Build Time
BUILDTIME=$(shell date +%s)

# Bash data
SCRIPTPATH=$(shell pwd -P)
CORES=$(shell grep -c ^processor /proc/cpuinfo)
ARCH=$(shell arch)

major=$(shell echo $(VERSION) | cut -d. -f1)
minor=$(shell echo $(VERSION) | cut -d. -f2)
micro=$(shell echo $(VERSION) | cut -d. -f3)
TESTVERSION=$(major)$(minor)

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

ifeq ($(shell if [[ "$(TESTVERSION)" -ge "70" ]]; then echo 0; else echo 1; fi;), 0)
PHP70ARGS="--with-argon2=shared,$(ARGON2_DIR)"
endif

ifeq ($(shell if [[ "$(TESTVERSION)" -ge "72" ]]; then echo 0; else echo 1; fi;), 0)
PHP71ARGS="--with-password-argon2=$(ARGON2_DIR)"
endif

RELEASENAME=php$(major).$(minor)-fpm
PROVIDES=php$(major).$(minor)-fpm

CHDIR_SHELL := $(SHELL)
define chdir
   $(eval _D=$(firstword $(1) $(@D)))
   $(info $(MAKE): cd $(_D)) $(eval SHELL = cd $(_D); $(CHDIR_SHELL))
endef

build: openssl curl libraries php

openssl:
	echo $(OPENSSL_PATH)
	rm -rf /tmp/openssl*
	cd /tmp && \
	wget https://www.openssl.org/source/openssl-$(OPENSSLVERSION).tar.gz && \
	tar -xf openssl-$(OPENSSLVERSION).tar.gz

	if [[ "$(ARCH)" == "arm"* ]]; then \
		cd /tmp/openssl-$(OPENSSLVERSION) && ./config --prefix=$(OPENSSL_PATH) no-shared enable-tlsext no-ssl2 no-ssl3; \
	else \
		cd /tmp/openssl-$(OPENSSLVERSION) && \
		wget https://raw.githubusercontent.com/cloudflare/sslconfig/master/patches/openssl__chacha20_poly1305_draft_and_rfc_ossl102g.patch && \
		patch -p1 < openssl__chacha20_poly1305_draft_and_rfc_ossl102g.patch 2>/dev/null; true && \
		wget https://gist.githubusercontent.com/charlesportwoodii/9e95c6a4ecde31ea23c17f6823bdb320/raw/a02fac917fc30f4767fb60a9563bad69dc1c054d/chacha.patch && \
		patch < chacha.patch 2>/dev/null; true && \
		./config --prefix=$(OPENSSL_PATH) no-shared enable-ec_nistp_64_gcc_128 enable-tlsext no-ssl2 no-ssl3; \
	fi 

	cd /tmp/openssl-$(OPENSSLVERSION) && \
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
	LIBS="-ldl" env PKG_CONFIG_PATH=$(OPENSSL_PATH)/lib/pkgconfig ./configure --prefix=$(NGHTTP_PREFIX) --enable-static=yes --enable-shared=no && \
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

# Only build libargon2 for PHP 7.0+
libargon2:
ifeq ($(shell if [[ "$(TESTVERSION)" -ge "70" ]]; then echo 0; else echo 1; fi;), 0)
	rm -rf $(ARGON2_DIR)
	
	cd /tmp && \
	git clone https://github.com/P-H-C/phc-winner-argon2 -b $(ARGON2VERSION) libargon2 && \
	cd $(ARGON2_DIR) && \
	CFLAGS="-fPIC" make

	cd $(ARGON2_DIR) && \
	ln -s . lib && \
	ln -s . libs

	rm -rf $(ARGON2_DIR)/libargon2.so*
endif

libsodium:
	rm -rf $(LIBSODIUM_DIR)

	cd /tmp && \
	git clone -b $(LIBSODIUMVERSION) https://github.com/jedisct1/libsodium.git && \
	cd /tmp/libsodium && \
	rm -rf /tmp/libsodium/lib && \
	./autogen.sh && \
	./configure --disable-shared --disable-pie && \
	CFLAGS="-fPIC" make install

libraries: libargon2 libsodium

php:
	rm -rf /tmp/php-$(VERSION)
	echo Building for PHP $(VERSION)

	cd /tmp && \
	git clone --depth 15 -b php-$(VERSION) https://github.com/php/php-src.git /tmp/php-$(VERSION)

	# Checkout PHP	
	cd /tmp/php-$(VERSION) && git checkout tags/php-$(VERSION)

	cd /tmp/php-$(VERSION)/ext && git clone -b $(REDISEXTVERSION) https://github.com/phpredis/phpredis redis

ifeq ($(shell if [[ "$(TESTVERSION)" -ge "70" ]]; then echo 0; else echo 1; fi;), 0)
	# Only download the Argon2 PHP extension for PHP 7.0+
	cd /tmp/php-$(VERSION)/ext && git clone -b $(ARGON2EXTVERSION) https://github.com/charlesportwoodii/php-argon2-ext argon2

	mkdir -p /tmp/php-$(VERSION)/ext/argon2
	cp -R $(ARGON2_DIR)/*  /tmp/php-$(VERSION)/ext/argon2/
endif

	cd /tmp/php-$(VERSION)/ext && git clone -b $(LIBSODIUMEXTVERSION) https://github.com/jedisct1/libsodium-php libsodium

	# Build
	cd /tmp/php-$(VERSION) && \
	./buildconf --force && \
	./configure CFLAGS="-I$(NGHTTP_PREFIX)/include" LDFLAGS="-L$(NGHTTP_PREFIX)/lib" \
		--with-libdir=lib64 \
		--build=x86_64-linux-gnu \
		--host=x86_64-linux-gnu \
		--prefix=/usr \
		--includedir=${prefix}/include/php/$(major).$(minor) \
		--mandir=${prefix}/share/man/php/$(major).$(minor) \
		--infodir=${prefix}/share/info/php/$(major).$(minor) \
		--sysconfdir=/etc \
		--localstatedir=/var \
		--program-suffix=$(major).$(minor) \
		--libdir=${prefix}/lib/php/$(major).$(minor) \
		--libexecdir=${prefix}/lib/php/$(major).$(minor) \
		--datadir=${prefix}/share/php/$(major).$(minor) \
		--libdir=${prefix}/lib/php/$(major).$(minor) \
		--libexecdir=${prefix}/lib/php/$(major).$(minor) \
		--with-config-file-path=/etc/php/$(major).$(minor) \
		--with-config-file-scan-dir=/etc/php/$(major).$(minor)/conf.d \
		--with-fpm-user=www-data \
		--disable-debug \
		--without-pear \
		--without-gdbm \
		--disable-short-tags \
		--with-curl=$(CURL_PREFIX) \
		--with-openssl=$(OPENSSL_PATH) \
		--enable-mysqlnd=shared \
		--with-pgsql=shared \
		--with-sqlite3=shared \
		--with-pdo-sqlite=shared \
		--with-pdo-mysql=shared,mysqlnd \
		--with-mysqli=shared,mysqlnd \
		--with-pdo-pgsql=shared \
		--with-mcrypt=shared \
		--with-xsl=shared \
		--with-libsodium=shared \
		--with-bz2=shared \
		--with-enchant=shared \
		--with-ldap=shared \
		--with-odbc=shared \
		--with-pspell=shared \
		--with-recode=shared \
		--with-gmp=shared \
		--with-readline \
		--with-jpeg-dir \
		--with-freetype-dir \
		--with-png-dir \
		--with-pic \
		--with-gettext \
		--with-iconv \
		--with-pcre-regex \
		--with-pcre-jit \
		--with-zlib \
		--with-layout=GNU \
		--with-gd=shared \
		--enable-gd-native-ttf \
    	--enable-gd-jis-conv \
		--with-mhash \
		--with-kerberos \
		--with-fileinfo \
		--enable-redis=shared \
		--enable-exif \
		--enable-ctype \
		--enable-hash \
		--enable-filter \
		--enable-shmop \
		--enable-calendar \
		--enable-sockets \
		--enable-sysvsem \
		--enable-sysvshm \
		--enable-sysvmsg \
		--enable-ftp \
		--enable-xml=shared \
		--enable-xmlreader=shared \
		--enable-mbstring=shared \
		--enable-zip=shared \
		--enable-intl=shared \
		--enable-soap=shared \
		--enable-json=shared \
		--enable-fpm \
		--enable-inline-optimization \
		--enable-pcntl \
		--enable-mbregex \
		--enable-mbregex-backtrack \
		--enable-opcache \
		--enable-opcache-file \
		--enable-huge-code-pages \
		--enable-bcmath \
		--enable-phar=static \
		$(PHP70ARGS) \
		$(PHP71ARGS) && \
	make -j$(CORES)

pear:
	rm -rf /tmp/php-pear
	rm -rf /tmp/php-pear-install
	mkdir -p /tmp/php-pear
	mkdir -p /tmp/php-pear-install
	wget -q https://pear.php.net/install-pear-nozlib.phar -O /tmp/php-pear/install-pear-nozlib.phar
	php /tmp/php-pear/install-pear-nozlib.phar
	rm -rf /tmp/php-pear-install/etc
	mkdir -p /tmp/php-pear-install/usr/share/php/pear
	mv /tmp/php-pear-install/lib/php/$(major).$(minor)/pear/.[!.]* /tmp/php-pear-install/usr/share/php/pear/
	mv /tmp/php-pear-install/lib/php/$(major).$(minor)/pear/* /tmp/php-pear-install/usr/share/php/pear/
	rm -rf /tmp/php-pear-install/lib

	fpm -s dir \
		-t deb \
		-n php-pear \
		-v 2:01~all \
		-C /tmp/php-pear-install \
		-p php-pear_2-01~all.deb \
		-m "charlesportwoodii@erianna.com" \
		--license "PHP License" \
		--url https://github.com/charlesportwoodii/php-fpm-build \
		--description "PHP PEAR" \
		--vendor "Charles R. Portwood II"

pre_package:
	# Removing the work build directory
	rm -rf /tmp/php-$(VERSION)-install

	# Install PHP FPM  to php-<version>-install for fpm
	cd /tmp/php-$(VERSION) && \
	make install INSTALL_ROOT=/tmp/php-$(VERSION)-install

	mkdir -p /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/conf.d
	mkdir -p /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/php-fpm.d

	mkdir -p /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available

	# Export the timezone as UTC 
	echo "date.timezone=UTC" >> /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/conf.d/UTC-timezone.ini
	
	# Secure Sessions defaults
	echo "session.use_cookies = 1" >> /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available/secure_session_cookies.ini
	echo "session.cookie_secure = 1" >> /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available/secure_session_cookies.ini
	echo "session.use_only_cookies = 1" >> /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available/secure_session_cookies.ini
	echo "session.cookie_httponly = 1" >> /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available/secure_session_cookies.ini
	echo "session.entropy_length = 32" >> /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available/secure_session_cookies.ini
	echo "session.entropy_file = /dev/urandom" >> /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available/secure_session_cookies.ini
	echo "session.hash_function = sha256" >> /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available/secure_session_cookies.ini
	echo "session.hash_bits_per_character = 5" >> /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available/secure_session_cookies.ini

	# Copy the FPM configuration
	cp $(SCRIPTPATH)/conf/php-fpm.conf /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/php-fpm.conf.default
	cp $(SCRIPTPATH)/conf/default.conf /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/php-fpm.d/pool.conf.default
	
	sed -i s/VERSION/$(major).$(minor)/g /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/php-fpm.conf.default
	sed -i s/VERSION/$(major).$(minor)/g /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/php-fpm.d/pool.conf.default
	sed -i s/PORT/$(major)$(minor)/g /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/php-fpm.d/pool.conf.default

	mkdir -p /tmp/php-$(VERSION)-install/lib/systemd/system
	cp $(SCRIPTPATH)/php-fpm.service /tmp/php-$(VERSION)-install/lib/systemd/system/php-fpm-$(major).$(minor).service
	sed -i s/VERSION/$(major).$(minor)/g /tmp/php-$(VERSION)-install/lib/systemd/system/php-fpm-$(major).$(minor).service

	# Copy the PHP.ini configuration
	cp /tmp/php-$(VERSION)/php.ini* /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)

	# Remove useless items in /usr/lib/etc
	rm -rf /tmp/php-$(VERSION)-install/usr/local/etc/php-fpm.conf.default
	rm -rf /tmp/php-$(VERSION)-install/etc

	# Copy the license file
	cp /tmp/php-$(VERSION)/LICENSE /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)
	
	# Copy init.d for non systemd systems
	mkdir -p /tmp/php-$(VERSION)-install/usr/local/etc/init.d
	cp $(SCRIPTPATH)/debian/init-php-fpm /tmp/php-$(VERSION)-install/usr/local/etc/init.d/php-fpm-$(major).$(minor)
	sed -i s/VERSION/$(major).$(minor)/g /tmp/php-$(VERSION)-install/usr/local/etc/init.d/php-fpm-$(major).$(minor)

	# Copy the local configuration files
	mkdir -p /tmp/php-$(VERSION)/debian
	mkdir -p /tmp/php-$(VERSION)/rpm
	cp $(SCRIPTPATH)/debian/* /tmp/php-$(VERSION)/debian
	cp $(SCRIPTPATH)/rpm/* /tmp/php-$(VERSION)/rpm

	# Edit packaging files for the right version
	sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/debian/postinstall-pak
	sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/rpm/postinstall
	sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/debian/preinstall-pak
	sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/rpm/preinstall
	sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/debian/preremove-pak
	sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/rpm/preremove

	# Remove phar to be packaged in a separate repository
	rm -rf /tmp/php-$(VERSION)-install/etc/pear.conf
	rm -rf /tmp/php-$(VERSION)-install/.registry
	rm -rf /tmp/php-$(VERSION)-install/.channels
	rm -rf /tmp/php-$(VERSION)-install/.depdblock
	rm -rf /tmp/php-$(VERSION)-install/.filemap
	rm -rf /tmp/php-$(VERSION)-install/.depdb
	rm -rf /tmp/php-$(VERSION)-install/.lock
	rm -rf /tmp/php-$(VERSION)-install/usr/bin/phar
	rm -rf /tmp/php-$(VERSION)-install/usr/bin/phar.phar

	# Make log and runtime directory
	mkdir -p /tmp/php-$(VERSION)-install/var/log/php/$(major).$(minor)
	mkdir -p /tmp/php-$(VERSION)-install/var/run/php/$(major).$(minor)

pre_package_ext:
	$(eval PHPAPI := $(shell /tmp/php-7.1.6/sapi/cli/php -i | grep 'PHP API' | sed -e 's/PHP API => //'))
	
	# Clean up of realized extensions
	for ext in $(REALIZED_EXTENSIONS); do \
		rm -rf /tmp/php$(VERSION)-$$ext; \
	done;

	# Extensions are to be packaged separately
	for ext in $(SHARED_EXTENSIONS) $(SHARED_ZEND_EXTENSIONS); do \
		rm -rf /tmp/php$(VERSION)-$$ext; \
		mkdir -p /tmp/php$(VERSION)-$$ext/usr/local/etc/php/$(major).$(minor)/mods-available; \
		mkdir -p /tmp/php$(VERSION)-$$ext/lib/php/$(major).$(minor)/$(PHPAPI)/; \
		mkdir -p /tmp/php$(VERSION)-$$ext/include/php/$(major).$(minor)/php/ext/$$ext/; \
		echo "zend_extension=$$ext.so" > /tmp/php$(VERSION)-$$ext/usr/local/etc/php/$(major).$(minor)/mods-available/$$ext.ini; \
		cp /tmp/php-$(VERSION)/modules/$$ext.* /tmp/php$(VERSION)-$$ext/lib/php/$(major).$(minor)/$(PHPAPI)/; \
		cp -R /tmp/php-$(VERSION)-install/include/php/$(major).$(minor)/php/ext/$$ext/* /tmp/php$(VERSION)-$$ext/include/php/$(major).$(minor)/php/ext/$$ext/; \
		rm -rf /tmp/php-$(VERSION)-install/include/php/$(major).$(minor)/php/ext/$$ext/; \
	done;

	rm -rf /tmp/php-$(VERSION)-install/lib/php/$(major).$(minor)/$(PHPAPI)/

	# Add some Opcache defaults
	echo "opcache.enable = true" >> /tmp/php$(VERSION)-opcache/usr/local/etc/php/$(major).$(minor)/mods-available/opcache.ini;
	echo "opcache.enable_cli = true" >> /tmp/php$(VERSION)-opcache/usr/local/etc/php/$(major).$(minor)/mods-available/opcache.ini;
	echo "opcache.error_log = /var/log/php.log" >> /tmp/php$(VERSION)-opcache/usr/local/etc/php/$(major).$(minor)/mods-available/opcache.ini;
	echo "opcache.save_comments = false" >> /tmp/php$(VERSION)-opcache/usr/local/etc/php/$(major).$(minor)/mods-available/opcache.ini;
	echo "opcache.enable_file_override = true" >> /tmp/php$(VERSION)-opcache/usr/local/etc/php/$(major).$(minor)/mods-available/opcache.ini;
	echo "opcache.memory_consumption=128" >> /tmp/php$(VERSION)-opcache/usr/local/etc/php/$(major).$(minor)/mods-available/opcache.ini;
	echo "opcache.max_accelerated_files=10000" >> /tmp/php$(VERSION)-opcache/usr/local/etc/php/$(major).$(minor)/mods-available/opcache.ini;
	echo "opcache.max_wasted_percentage=10" >> /tmp/php$(VERSION)-opcache/usr/local/etc/php/$(major).$(minor)/mods-available/opcache.ini;
	echo "opcache.validate_timestamps=0" >> /tmp/php$(VERSION)-opcache/usr/local/etc/php/$(major).$(minor)/mods-available/opcache.ini;

	# Merge Sqlite
	cp -R /tmp/php$(VERSION)-pdo_sqlite/* /tmp/php$(VERSION)-sqlite3/
	rm -rf /tmp/php$(VERSION)-pdo_sqlite
	rm -rf /tmp/php$(VERSION)-sqlite3/usr/local/etc/php/$(major).$(minor)/mods-available/*
	echo "extension=sqlite3.so" > /tmp/php$(VERSION)-sqlite3/usr/local/etc/php/$(major).$(minor)/mods-available/sqlite3.ini;
	echo "extension=pdo_sqlite.so" > /tmp/php$(VERSION)-sqlite3/usr/local/etc/php/$(major).$(minor)/mods-available/sqlite3.ini;

	# Merge MySQL
	mkdir -p /tmp/php$(VERSION)-mysql/
	cp -R /tmp/php$(VERSION)-mysqli/* /tmp/php$(VERSION)-mysql/
	rm -rf /tmp/php$(VERSION)-mysqli
	cp -R /tmp/php$(VERSION)-mysqlnd/* /tmp/php$(VERSION)-mysql/
	rm -rf /tmp/php$(VERSION)-mysqlnd
	cp -R /tmp/php$(VERSION)-pdo_mysql/* /tmp/php$(VERSION)-mysql/
	rm -rf /tmp/php$(VERSION)-pdo_mysql
	rm -rf /tmp/php$(VERSION)-mysql/usr/local/etc/php/$(major).$(minor)/mods-available/*

	echo "extension=mysqlnd.so" > /tmp/php$(VERSION)-mysql/usr/local/etc/php/$(major).$(minor)/mods-available/mysql.ini;
	echo "extension=mysqli.so" > /tmp/php$(VERSION)-mysql/usr/local/etc/php/$(major).$(minor)/mods-available/mysql.ini;
	echo "extension=pdo_mysql.so" > /tmp/php$(VERSION)-mysql/usr/local/etc/php/$(major).$(minor)/mods-available/mysql.ini;

	# Merge pgsql
	cp -R /tmp/php$(VERSION)-pdo_pgsql/* /tmp/php$(VERSION)-pgsql/
	rm -rf /tmp/php$(VERSION)-pdo_pgsql
	rm -rf /tmp/php$(VERSION)-pgsql/usr/local/etc/php/$(major).$(minor)/mods-available/*
	echo "extension=pgsql.so" > /tmp/php$(VERSION)-pgsql/usr/local/etc/php/$(major).$(minor)/mods-available/pgsql.ini;
	echo "extension=pdo_pgsql.so" > /tmp/php$(VERSION)-pgsql/usr/local/etc/php/$(major).$(minor)/mods-available/pgsql.ini;

	for ext in $(REALIZED_EXTENSIONS); do \
		mkdir -p /tmp/php$(VERSION)-$$ext/etc/php/$(major).$(minor)/mods-available; \
		ln -s /usr/local/etc/php/$(major).$(minor)/mods-available/$$ext.ini /tmp/php$(VERSION)-$$ext/etc/php/$(major).$(minor)/mods-available/$$ext.ini; \
	done;

fpm_debian: pre_package pre_package_ext
	echo "Building native package for debian"

	fpm -s dir \
		-t deb \
		-n $(RELEASENAME) \
		-v $(VERSION)-$(RELEASEVER)~$(shell lsb_release --codename | cut -f2) \
		-C /tmp/php-$(VERSION)-install \
		-p $(RELEASENAME)_$(micro)-$(RELEASEVER)~$(shell lsb_release --codename | cut -f2)_$(shell uname -m).deb \
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
		--depends "libfreetype6 > 0" \
		--depends "libpng12-0 > 0" \
		--deb-systemd-restart-after-upgrade \
		--template-scripts \
		--force \
		--no-deb-auto-config-files \
		--before-install /tmp/php-$(VERSION)/debian/preinstall-pak \
		--after-install /tmp/php-$(VERSION)/debian/postinstall-pak \
		--before-remove /tmp/php-$(VERSION)/debian/preremove-pak \
		--deb-compression=gz \
		--provides "php$(major).$(minor)-common php$(major).$(minor)-cli php$(major).$(minor)-curl php$(major).$(minor)-iconv php$(major).$(minor)-common php$(major).$(minor)-calendar php$(major).$(minor)-exif php$(major).$(minor)-hash php$(major).$(minor)-sockets php$(major).$(minor)-sysvsem php$(major).$(minor)-sysvshm php$(major).$(minor)-sysvmsg php$(major).$(minor)-ctype php$(major).$(minor)-filter php$(major).$(minor)-ftp php$(major).$(minor)-fileinfo php$(major).$(minor)-gettext php$(major).$(minor)-phar"

	for ext in $(REALIZED_EXTENSIONS); do \
		fpm -s dir \
			-t deb \
			-n "php$(major).$(minor)-$$ext" \
			-v $(VERSION)-$(RELEASEVER)~$(shell lsb_release --codename | cut -f2) \
			-C "/tmp/php$(VERSION)-$$ext" \
			-p "php$(major).$(minor).$(micro)-$$ext-$(RELEASEVER)~$(shell lsb_release --codename | cut -f2)_$(shell uname -m).deb" \
			-m "charlesportwoodii@erianna.com" \
			--license "PHP License" \
			--url https://github.com/charlesportwoodii/php-fpm-build \
			--description "PHP $$ext, $(VERSION)" \
			--vendor "Charles R. Portwood II" \
			--depends "php$(major).$(minor)-fpm" \
			--deb-systemd-restart-after-upgrade \
			--deb-compression=gz \
			--template-scripts \
			--force \
			--no-deb-auto-config-files; \
	done;
	
fpm_rpm: pre_package pre_package_ext
	echo "Building native package for rpm"

	fpm -s dir \
		-t rpm \
		-n $(RELEASENAME) \
		-v $(VERSION)-$(RELEASEVER)~$(shell arch) \
		-C /tmp/php-$(VERSION)-install \
		-p $(RELEASENAME)_$(micro)-$(RELEASEVER)~$(shell arch).rpm \
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
		--depends "libpng > 0" \
		--depends "freetype > 0" \
		--depends "freetype-devel > 0" \
		--rpm-digest sha384 \
		--rpm-compression gzip \
		--template-scripts \
		--force \
		--before-install /tmp/php-$(VERSION)/rpm/preinstall \
		--after-install /tmp/php-$(VERSION)/rpm/postinstall \
		--before-remove /tmp/php-$(VERSION)/rpm/preremove \
		--provides "php$(major).$(minor)-common php$(major).$(minor)-cli php$(major).$(minor)-curl php$(major).$(minor)-iconv php$(major).$(minor)-common php$(major).$(minor)-calendar php$(major).$(minor)-exif php$(major).$(minor)-hash php$(major).$(minor)-sockets php$(major).$(minor)-sysvsem php$(major).$(minor)-sysvshm php$(major).$(minor)-sysvmsg php$(major).$(minor)-ctype php$(major).$(minor)-filter php$(major).$(minor)-ftp php$(major).$(minor)-fileinfo php$(major).$(minor)-gettext php$(major).$(minor)-phar"
		
	for ext in $(REALIZED_EXTENSIONS); do \
		fpm -s dir \
			-t rpm \
			-n "php$(major).$(minor)-$$ext" \
			-v $(VERSION)-$(RELEASEVER)~$(shell arch) \
			-C "/tmp/php$(VERSION)-$$ext" \
			-p "php$(major).$(minor).$(micro)-$$ext-$(RELEASEVER)~$(shell arch).rpm" \
			-m "charlesportwoodii@erianna.com" \
			--license "PHP License" \
			--url https://github.com/charlesportwoodii/php-fpm-build \
			--description "PHP $$ext, $(VERSION)" \
			--vendor "Charles R. Portwood II" \
			--depends "php$(major).$(minor)-fpm" \
			--rpm-digest sha384 \
			--rpm-compression gzip \
			--template-scripts \
			--force; \
	done;
