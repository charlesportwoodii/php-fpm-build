SHELL := /bin/bash

# Dependency Versions
PCREVERSION?=8.41
OPENSSLVERSION?=1.0.2m
CURLVERSION?=7_57_0
NGHTTPVERSION?=1.28.0
RELEASEVER?=1

# Library versions
ARGON2VERSION?=20161029
LIBSODIUMVERSION?=1.0.15

# External extension versions
REDISEXTVERSION?=3.1.4
ARGON2EXTVERSION?=1.2.1
LIBSODIUMEXTVERSION?=2.0.7

SHARED_EXTENSIONS := pdo_sqlite pdo_pgsql pdo_mysql pgsql mysqlnd mysqli sqlite3 xml mbstring zip intl redis mcrypt xsl bz2 gd enchant ldap pspell recode argon2 sodium gmp soap
SHARED_ZEND_EXTENSIONS := opcache
REALIZED_EXTENSIONS := opcache sqlite3 mysql pgsql xml mbstring zip intl redis mcrypt xsl bz2 gd enchant ldap pspell recode argon2 sodium gmp soap

# Reference library implementations
ARGON2_DIR=/tmp/libargon2
LIBSODIUM_DIR=/tmp/libsodium

# Current Build Time
BUILDTIME=$(shell date +%s)

# Bash data
SCRIPTPATH=$(shell pwd -P)
CORES?=$(shell grep -c ^processor /proc/cpuinfo)
ARCH=$(shell arch)

major=$(shell echo $(VERSION) | cut -d. -f1)
minor=$(shell echo $(VERSION) | cut -d. -f2)
micro=$(shell echo $(VERSION) | cut -d. -f3)
TESTVERSION=$(major)$(minor)

# Declare the package name
PKG_NAME=php$(major).$(minor)

# Sub packages that will be created as part of a separate build
SUBPACKAGES=cgi fpm dev

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

# Argon2 extension can be enabled for PHP 7.0+
ifeq ($(shell if [[ "$(TESTVERSION)" -ge "70" ]]; then echo 0; else echo 1; fi;), 0)
PHP70ARGS="--with-argon2=shared,$(ARGON2_DIR)"
endif

# Mcrypt is only available in PHP 7.1 and lower
ifeq ($(shell if [[ "$(TESTVERSION)" -lt "72" ]]; then echo 0; else echo 1; fi;), 0)
PHP71ARGS="--with-mcrypt=shared"
PHP71_RPM_DEPENDS=--depends "libmcrypt > 0"
PHP71_DEB_DEPENDS=--depends "libmcrypt4 > 0"
PHP71_APK_DEPENDS=--depends "libmcrypt > 0"
endif

# PASSWORD_ARGON2 is only available in PHP 7.2
ifeq ($(shell if [[ "$(TESTVERSION)" -ge "72" ]]; then echo 0; else echo 1; fi;), 0)
PHP72ARGS="--with-password-argon2=$(ARGON2_DIR)"
endif

# Alpine Linux needs to use system libraries for sqlite to prevent linker failures
ifeq ($(shell if [ -f /etc/alpine-release ]; then echo 0; else echo 1; fi;), 0)
SQLITEARGS=--with-sqlite3=shared,/usr
PDOSQLITEARGS=--with-pdo-sqlite=sharefd,/usr
else
SQLITEARGS=--with-sqlite3=shared
PDOSQLITEARGS=--with-pdo-sqlite=shared
endif

RELEASENAME=$(PKG_NAME)-common
PROVIDES=$(PKG_NAME)-common

CHDIR_SHELL := $(SHELL)
define chdir
   $(eval _D=$(firstword $(1) $(@D)))
   $(info $(MAKE): cd $(_D)) $(eval SHELL = cd $(_D); $(CHDIR_SHELL))
endef

build: openssl curl libraries php

clean_dist:
	rm -rf *.deb
	rm -rf *.apk
	rm -rf *.rpm

determine_extensions:
ifeq ($(shell if [[ "$(TESTVERSION)" -ge "72" ]]; then echo 0; else echo 1; fi;), 0)
	$(eval SHARED_EXTENSIONS:= $(shell echo $(SHARED_EXTENSIONS) | sed s/mcrypt//g))
	$(eval REALIZED_EXTENSIONS:= $(shell echo $(REALIZED_EXTENSIONS) | sed s/mcrypt//g))
endif

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
	wget https://github.com/nghttp2/nghttp2/releases/download/v$(NGHTTPVERSION)/nghttp2-$(NGHTTPVERSION).tar.gz && \
	tar -xf nghttp2-$(NGHTTPVERSION).tar.gz && \
	cd nghttp2-$(NGHTTPVERSION) && \
	LIBS="-ldl" env PKG_CONFIG_PATH=$(OPENSSL_PATH)/lib/pkgconfig \
	./configure \
		--prefix=$(NGHTTP_PREFIX) \
		--enable-static=yes \
		--enable-shared=no \
		--disable-python-bindings && \
	make -j$(CORES) && \
	make install && \
	cd $(NGHTTP_PREFIX) && \
	ln -fs lib lib64

curl: nghttp2
	echo $(CURL_PREFIX)
	rm -rf /tmp/curl*
	cd /tmp && \
	wget https://github.com/curl/curl/releases/download/curl-$(CURLVERSION)/curl-$(shell echo $(CURLVERSION) | tr '_' '.').tar.gz && \
	tar -xf curl-$(shell echo $(CURLVERSION) | tr '_' '.').tar.gz && \
	cd curl-$(shell echo $(CURLVERSION) | tr '_' '.') && \
	LD_LIBRARY_PATH=/usr/local/lib LIBS="-ldl" env PKG_CONFIG_PATH=$(OPENSSL_PATH)/lib/pkgconfig \
	./configure  \
		--prefix=$(CURL_PREFIX) \
		--with-ssl \
		--disable-shared \
		--disable-ldap \
		--with-libssl-prefix=$(OPENSSL_PATH) \
		--with-nghttp2=$(NGHTTP_PREFIX) \
		--disable-ldaps && \
	make -j$(CORES) && \
	make install && \
	cd $(CURL_PREFIX) && \
	ln -fs lib lib64 && \
	rm $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc

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
	ln -s . lib64 && \
	ln -s . libs

	rm -rf $(ARGON2_DIR)/libargon2.so*
endif

libsodium:
	rm -rf /tmp/libsodium*

	cd /tmp && \
	wget https://github.com/jedisct1/libsodium/releases/download/$(LIBSODIUMVERSION)/libsodium-$(LIBSODIUMVERSION).tar.gz && \
	tar -xf libsodium-$(LIBSODIUMVERSION).tar.gz && \
	mv libsodium-$(LIBSODIUMVERSION) $(LIBSODIUM_DIR) && \
	cd libsodium && \
	rm -rf /tmp/libsodium/lib && \
	./configure --disable-shared --disable-pie && \
	CFLAGS="-fPIC" make install

libraries: libargon2 libsodium

php: determine_extensions
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

# Libsodium is bundled with PHP in 7.2
ifeq ($(shell if [[ "$(TESTVERSION)" -lt "72" ]]; then echo 0; else echo 1; fi;), 0)
	cd /tmp/php-$(VERSION)/ext && git clone -b $(LIBSODIUMEXTVERSION) https://github.com/jedisct1/libsodium-php sodium
endif

	# Build
	cd /tmp/php-$(VERSION) && \
	./buildconf --force && \
	./configure LIBS="-lpthread" CFLAGS="-I$(NGHTTP_PREFIX)/include -I$(CURL_PREFIX)/include" LDFLAGS="-L$(NGHTTP_PREFIX)/lib -L$(CURL_PREFIX)/lib" \
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
		--with-pdo-mysql=shared,mysqlnd \
		--with-mysqli=shared,mysqlnd \
		--with-pdo-pgsql=shared \
		--with-xsl=shared \
		--with-sodium=shared \
		--with-bz2=shared \
		--with-enchant=shared \
		--with-ldap=shared \
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
		--enable-mbstring=shared \
		--enable-zip=shared \
		--enable-intl=shared \
		--enable-soap=shared \
		--enable-json \
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
		$(SQLITEARGS) \
		$(PDOSQLITEARGS) \
		$(PHP70ARGS) \
		$(PHP71ARGS) \
		$(PHP72ARGS) && \
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
	rm -rf /tmp/php-$(VERSION)-install*

	# Install PHP FPM  to php-<version>-install for fpm
	cd /tmp/php-$(VERSION) && \
	make install INSTALL_ROOT=/tmp/php-$(VERSION)-install

	# Copy the local configuration files
	mkdir -p /tmp/php-$(VERSION)/debian
	mkdir -p /tmp/php-$(VERSION)/rpm
	mkdir -p /tmp/php-$(VERSION)/alpine
	cp -R $(SCRIPTPATH)/debian/* /tmp/php-$(VERSION)/debian
	cp -R $(SCRIPTPATH)/rpm/* /tmp/php-$(VERSION)/rpm
	cp -R $(SCRIPTPATH)/alpine/* /tmp/php-$(VERSION)/alpine

	# Replace the subpackages
	sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/debian/common/postinstall-pak
	sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/debian/common/preremove-pak
	sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/rpm/common/postinstall
	sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/alpine/common/post-install

	# Build out the subpackage structure
	for pkg in $(SUBPACKAGES); do \
		mkdir -p /tmp/php-$(VERSION)-install-$$pkg/usr/bin; \
		mkdir -p /tmp/php-$(VERSION)-install-$$pkg/usr/sbin; \
		mkdir -p /tmp/php-$(VERSION)-install-$$pkg/share/man/php/$(major).$(minor)/man1; \
		mkdir -p /tmp/php-$(VERSION)-install-$$pkg/share/man/php/$(major).$(minor)/man8; \
		sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/debian/$$pkg/postinstall-pak; \
		sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/debian/$$pkg/preinstall-pak; \
		sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/debian/$$pkg/preremove-pak; \
		sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/alpine/$$pkg/post-install; \
		sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/alpine/$$pkg/pre-install; \
		sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/alpine/$$pkg/pre-deinstall; \
		sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/rpm/$$pkg/postinstall; \
		sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/rpm/$$pkg/preinstall; \
		sed -i s/VERSION=/VERSION=$(major).$(minor)/g /tmp/php-$(VERSION)/rpm/$$pkg/preremove; \
	done;

	# FPM
	mv /tmp/php-$(VERSION)-install/usr/sbin/php-fpm$(major).$(minor) /tmp/php-$(VERSION)-install-fpm/usr/sbin/
	mv /tmp/php-$(VERSION)-install/share/man/php/$(major).$(minor)/man8/php-fpm* /tmp/php-$(VERSION)-install-fpm/share/man/php/$(major).$(minor)/man8

	mkdir -p /tmp/php-$(VERSION)-install-fpm/usr/local/etc/php/$(major).$(minor)/php-fpm.d
	cp $(SCRIPTPATH)/conf/php-fpm.conf /tmp/php-$(VERSION)-install-fpm/usr/local/etc/php/$(major).$(minor)/php-fpm.conf.default
	cp $(SCRIPTPATH)/conf/default.conf /tmp/php-$(VERSION)-install-fpm/usr/local/etc/php/$(major).$(minor)/php-fpm.d/pool.conf.default
	
	sed -i s/VERSION/$(major).$(minor)/g /tmp/php-$(VERSION)-install-fpm/usr/local/etc/php/$(major).$(minor)/php-fpm.conf.default
	sed -i s/VERSION/$(major).$(minor)/g /tmp/php-$(VERSION)-install-fpm/usr/local/etc/php/$(major).$(minor)/php-fpm.d/pool.conf.default
	sed -i s/PORT/$(major)$(minor)/g /tmp/php-$(VERSION)-install-fpm/usr/local/etc/php/$(major).$(minor)/php-fpm.d/pool.conf.default

	mkdir -p /tmp/php-$(VERSION)-install-fpm/lib/systemd/system
	cp $(SCRIPTPATH)/php-fpm.service /tmp/php-$(VERSION)-install-fpm/lib/systemd/system/php-fpm-$(major).$(minor).service
	sed -i s/VERSION/$(major).$(minor)/g /tmp/php-$(VERSION)-install-fpm/lib/systemd/system/php-fpm-$(major).$(minor).service

	mkdir -p /tmp/php-$(VERSION)-install-fpm/usr/local/etc/init.d
	cp $(SCRIPTPATH)/debian/fpm/init-php-fpm /tmp/php-$(VERSION)-install-fpm/usr/local/etc/init.d/php-fpm-$(major).$(minor)
	sed -i s/VERSION/$(major).$(minor)/g /tmp/php-$(VERSION)-install-fpm/usr/local/etc/init.d/php-fpm-$(major).$(minor)

	mkdir -p /tmp/php-$(VERSION)-install-fpm/usr/local/etc/init.d
	cp $(SCRIPTPATH)/alpine/php-fpm.rc /tmp/php-$(VERSION)-install-fpm/usr/local/etc/init.d/php-fpm-$(major).$(minor)
	sed -i s/VERSION/$(major).$(minor)/g /tmp/php-$(VERSION)-install-fpm/usr/local/etc/init.d/php-fpm-$(major).$(minor)

	# CGI
	mv /tmp/php-$(VERSION)-install/usr/bin/php-cgi$(major).$(minor) /tmp/php-$(VERSION)-install-cgi/usr/bin/
	mv /tmp/php-$(VERSION)-install/share/man/php/$(major).$(minor)/man1/php-cgi* /tmp/php-$(VERSION)-install-cgi/share/man/php/$(major).$(minor)/man1

	# DEV
	mv /tmp/php-$(VERSION)-install/usr/bin/phpdbg$(major).$(minor) /tmp/php-$(VERSION)-install-dev/usr/bin/
	mv /tmp/php-$(VERSION)-install/usr/bin/phpize$(major).$(minor) /tmp/php-$(VERSION)-install-dev/usr/bin/
	mv /tmp/php-$(VERSION)-install/usr/bin/php-config$(major).$(minor) /tmp/php-$(VERSION)-install-dev/usr/bin/

	mv /tmp/php-$(VERSION)-install/share/man/php/$(major).$(minor)/man1/phpdbg$(major).$(minor).1 /tmp/php-$(VERSION)-install-dev/share/man/php/$(major).$(minor)/man1
	mv /tmp/php-$(VERSION)-install/share/man/php/$(major).$(minor)/man1/phpize$(major).$(minor).1 /tmp/php-$(VERSION)-install-dev/share/man/php/$(major).$(minor)/man1
	mv /tmp/php-$(VERSION)-install/share/man/php/$(major).$(minor)/man1/php-config$(major).$(minor).1 /tmp/php-$(VERSION)-install-dev/share/man/php/$(major).$(minor)/man1
	mkdir -p /tmp/php-$(VERSION)-install-dev/lib/php/$(major).$(minor)/build
	mv /tmp/php-$(VERSION)-install/lib/php/$(major).$(minor)/build/* /tmp/php-$(VERSION)-install-dev/lib/php/$(major).$(minor)/build/

	# Common
	mkdir -p /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/conf.d
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

	# Copy the PHP.ini configuration
	cp /tmp/php-$(VERSION)/php.ini* /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)

	# Remove useless items in /usr/lib/etc
	rm -rf /tmp/php-$(VERSION)-install/usr/local/etc/php-fpm.conf.default
	rm -rf /tmp/php-$(VERSION)-install/etc

	# Copy the license file
	cp /tmp/php-$(VERSION)/LICENSE /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)
	
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
	rm -rf /tmp/php-$(VERSION)-install/share/man/php/$(major).$(minor)/phar.1
	rm -rf /tmp/php-$(VERSION)-install/share/man/php/$(major).$(minor)/phar.phar.1

	# Make log and runtime directory
	mkdir -p /tmp/php-$(VERSION)-install/var/log/php/$(major).$(minor)
	mkdir -p /tmp/php-$(VERSION)-install/var/run/php/$(major).$(minor)

pre_package_ext: determine_extensions
	$(eval PHPAPI := $(shell /tmp/php-$$VERSION/sapi/cli/php -i | grep 'PHP API' | sed -e 's/PHP API => //'))

	# Clean up of realized extensions
	for ext in $(REALIZED_EXTENSIONS); do \
		rm -rf /tmp/php$(VERSION)-$$ext; \
	done;

	# Extensions are to be packaged separately
	for ext in $(SHARED_EXTENSIONS); do \
		rm -rf /tmp/php$(VERSION)-$$ext; \
		mkdir -p /tmp/php$(VERSION)-$$ext/usr/local/etc/php/$(major).$(minor)/mods-available; \
		mkdir -p /tmp/php$(VERSION)-$$ext/lib/php/$(major).$(minor)/$(PHPAPI)/; \
		mkdir -p /tmp/php$(VERSION)-$$ext/include/php/$(major).$(minor)/php/ext/$$ext/; \
		echo "extension=$$ext.so" > /tmp/php$(VERSION)-$$ext/usr/local/etc/php/$(major).$(minor)/mods-available/$$ext.ini; \
		cp /tmp/php-$(VERSION)/modules/$$ext.* /tmp/php$(VERSION)-$$ext/lib/php/$(major).$(minor)/$(PHPAPI)/; \
		mv /tmp/php-$(VERSION)-install/include/php/$(major).$(minor)/php/ext/$$ext/* /tmp/php$(VERSION)-$$ext/include/php/$(major).$(minor)/php/ext/$$ext/; \
		rm -rf /tmp/php-$(VERSION)-install/include/php/$(major).$(minor)/php/ext/$$ext/; \
	done;
	
	for ext in $(SHARED_ZEND_EXTENSIONS); do \
		rm -rf /tmp/php$(VERSION)-$$ext; \
		mkdir -p /tmp/php$(VERSION)-$$ext/usr/local/etc/php/$(major).$(minor)/mods-available; \
		mkdir -p /tmp/php$(VERSION)-$$ext/lib/php/$(major).$(minor)/$(PHPAPI)/; \
		mkdir -p /tmp/php$(VERSION)-$$ext/include/php/$(major).$(minor)/php/ext/$$ext/; \
		echo "zend_extension=$$ext.so" > /tmp/php$(VERSION)-$$ext/usr/local/etc/php/$(major).$(minor)/mods-available/$$ext.ini; \
		cp /tmp/php-$(VERSION)/modules/$$ext.* /tmp/php$(VERSION)-$$ext/lib/php/$(major).$(minor)/$(PHPAPI)/; \
		mv /tmp/php-$(VERSION)-install/include/php/$(major).$(minor)/php/ext/$$ext/* /tmp/php$(VERSION)-$$ext/include/php/$(major).$(minor)/php/ext/$$ext/; \
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
	echo "extension=pdo_sqlite.so" >> /tmp/php$(VERSION)-sqlite3/usr/local/etc/php/$(major).$(minor)/mods-available/sqlite3.ini;

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
	echo "extension=mysqli.so" >> /tmp/php$(VERSION)-mysql/usr/local/etc/php/$(major).$(minor)/mods-available/mysql.ini;
	echo "extension=pdo_mysql.so" >> /tmp/php$(VERSION)-mysql/usr/local/etc/php/$(major).$(minor)/mods-available/mysql.ini;

	# Merge pgsql
	cp -R /tmp/php$(VERSION)-pdo_pgsql/* /tmp/php$(VERSION)-pgsql/
	rm -rf /tmp/php$(VERSION)-pdo_pgsql
	rm -rf /tmp/php$(VERSION)-pgsql/usr/local/etc/php/$(major).$(minor)/mods-available/*
	echo "extension=pgsql.so" > /tmp/php$(VERSION)-pgsql/usr/local/etc/php/$(major).$(minor)/mods-available/pgsql.ini;
	echo "extension=pdo_pgsql.so" >> /tmp/php$(VERSION)-pgsql/usr/local/etc/php/$(major).$(minor)/mods-available/pgsql.ini;

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
		-p $(PKG_NAME).$(micro)-common-$(RELEASEVER)~$(shell lsb_release --codename | cut -f2)_$(shell uname -m).deb \
		-m "charlesportwoodii@erianna.com" \
		--license "PHP License" \
		--url https://github.com/charlesportwoodii/php-fpm-build \
		--description "PHP FPM, $(VERSION)" \
		--vendor "Charles R. Portwood II" \
		--depends "libxml2 > 0" \
		--depends "libjpeg-turbo8 > 0" \
		--depends "$(LIBICU) > 0" \
		--depends "libpq5 > 0" \
		--depends "libfreetype6 > 0" \
		--depends "libpng12-0 > 0" \
		--depends "libenchant1c2a > 0" \
		--depends "aspell-en > 0" \
		--depends "librecode0 > 0" \
		--depends "libmysqlclient20 > 0" \
		$(PHP71_DEB_DEPENDS) \
		--deb-systemd-restart-after-upgrade \
		--template-scripts \
		--force \
		--no-deb-auto-config-files \
		--after-install /tmp/php-$(VERSION)/debian/common/postinstall-pak \
		--before-remove /tmp/php-$(VERSION)/debian/common/preremove-pak \
		--deb-compression=gz \
		--provides "$(PKG_NAME)-cli $(PKG_NAME)-curl $(PKG_NAME)-iconv $(PKG_NAME)-calendar $(PKG_NAME)-exif $(PKG_NAME)-hash $(PKG_NAME)-sockets $(PKG_NAME)-sysvsem $(PKG_NAME)-sysvshm $(PKG_NAME)-sysvmsg $(PKG_NAME)-ctype $(PKG_NAME)-filter $(PKG_NAME)-ftp $(PKG_NAME)-fileinfo $(PKG_NAME)-gettext $(PKG_NAME)-phar $(PKG_NAME)-json"

	for ext in $(REALIZED_EXTENSIONS); do \
		fpm -s dir \
			-t deb \
			-n "$(PKG_NAME)-$$ext" \
			-v $(VERSION)-$(RELEASEVER)~$(shell lsb_release --codename | cut -f2) \
			-C "/tmp/php$(VERSION)-$$ext" \
			-p "$(PKG_NAME).$(micro)-$$ext-$(RELEASEVER)~$(shell lsb_release --codename | cut -f2)_$(shell uname -m).deb" \
			-m "charlesportwoodii@erianna.com" \
			--license "PHP License" \
			--url https://github.com/charlesportwoodii/php-fpm-build \
			--description "PHP $$ext, $(VERSION)" \
			--vendor "Charles R. Portwood II" \
			--depends "$(PKG_NAME)-common" \
			--deb-systemd-restart-after-upgrade \
			--deb-compression=gz \
			--template-scripts \
			--force \
			--no-deb-auto-config-files; \
	done;

	for pkg in $(SUBPACKAGES); do \
		fpm -s dir \
			-t deb \
			-n "$(PKG_NAME)-$$pkg" \
			-v $(VERSION)-$(RELEASEVER)~$(shell lsb_release --codename | cut -f2) \
			-C "/tmp/php-$(VERSION)-install-$$pkg" \
			-p "$(PKG_NAME).$(micro)-$$pkg-$(RELEASEVER)~$(shell lsb_release --codename | cut -f2)_$(shell uname -m).deb" \
			-m "charlesportwoodii@erianna.com" \
			--license "PHP License" \
			--url https://github.com/charlesportwoodii/php-fpm-build \
			--description "PHP $$pkg, $(VERSION)" \
			--vendor "Charles R. Portwood II" \
			--depends "$(PKG_NAME)-common" \
			--deb-systemd-restart-after-upgrade \
			--deb-compression=gz \
			--template-scripts \
			--before-install /tmp/php-$(VERSION)/debian/$$pkg/preinstall-pak \
			--after-install /tmp/php-$(VERSION)/debian/$$pkg/postinstall-pak \
			--before-remove /tmp/php-$(VERSION)/debian/$$pkg/preremove-pak \
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
		--depends "libjpeg-turbo > 0" \
		--depends "libicu > 0" \
		--depends "postgresql-devel > 0" \
		--depends "libpng12 > 0" \
		--depends "libpng > 0" \
		--depends "freetype > 0" \
		--depends "freetype-devel > 0" \
		$(PHP71_RPM_DEPENDS) \
		--rpm-digest sha384 \
		--rpm-compression gzip \
		--template-scripts \
		--force \
		--after-install /tmp/php-$(VERSION)/rpm/common/postinstall \
		--provides "$(PKG_NAME)-cli $(PKG_NAME)-curl $(PKG_NAME)-iconv $(PKG_NAME)-calendar $(PKG_NAME)-exif $(PKG_NAME)-hash $(PKG_NAME)-sockets $(PKG_NAME)-sysvsem $(PKG_NAME)-sysvshm $(PKG_NAME)-sysvmsg $(PKG_NAME)-ctype $(PKG_NAME)-filter $(PKG_NAME)-ftp $(PKG_NAME)-fileinfo $(PKG_NAME)-gettext $(PKG_NAME)-phar $(PKG_NAME)-json"
		
	for ext in $(REALIZED_EXTENSIONS); do \
		fpm -s dir \
			-t rpm \
			-n "$(PKG_NAME)-$$ext" \
			-v $(VERSION)-$(RELEASEVER)~$(shell arch) \
			-C "/tmp/php$(VERSION)-$$ext" \
			-p "$(PKG_NAME).$(micro)-$$ext-$(RELEASEVER)~$(shell arch).rpm" \
			-m "charlesportwoodii@erianna.com" \
			--license "PHP License" \
			--url https://github.com/charlesportwoodii/php-fpm-build \
			--description "PHP $$ext, $(VERSION)" \
			--vendor "Charles R. Portwood II" \
			--depends "$(PKG_NAME)-fpm" \
			--rpm-digest sha384 \
			--rpm-compression gzip \
			--template-scripts \
			--force; \
	done;

	for pkg in $(SUBPACKAGES); do \
		fpm -s dir \
			-t rpm \
			-n "$(PKG_NAME)-$$pkg" \
			-v $(VERSION)-$(RELEASEVER)~$(shell arch) \
			-C "/tmp/php-$(VERSION)-install-$$pkg" \
			-p "$(PKG_NAME).$(micro)-$$pkg-$(RELEASEVER)~$(shell arch).rpm" \
			-m "charlesportwoodii@erianna.com" \
			--license "PHP License" \
			--url https://github.com/charlesportwoodii/php-fpm-build \
			--description "PHP $$pkg, $(VERSION)" \
			--vendor "Charles R. Portwood II" \
			--depends "$(PKG_NAME)-common" \
			--rpm-digest sha384 \
			--rpm-compression gzip \
			--template-scripts \
			--before-install /tmp/php-$(VERSION)/rpm/$$pkg/preinstall \
			--after-install /tmp/php-$(VERSION)/rpm/$$pkg/postinstall \
			--before-remove /tmp/php-$(VERSION)/rpm/$$pkg/preremove \
			--force; \
	done;

fpm_alpine: pre_package pre_package_ext
	/fpm/bin/fpm -s dir \
		-t apk \
		-n $(RELEASENAME) \
		-v $(VERSION)-$(RELEASEVER)~$(shell uname -m) \
		-C /tmp/php-$(VERSION)-install \
		-p $(RELEASENAME)-$(VERSION)-$(RELEASEVER)~$(shell uname -m).apk \
		-m "charlesportwoodii@erianna.com" \
		--license "PHP License" \
		--url https://github.com/charlesportwoodii/php-fpm-build \
		--description "PHP FPM, $(VERSION)" \
		--vendor "Charles R. Portwood II" \
		--depends "libxml2 > 0" \
		--depends "libjpeg > 0" \
		--depends "icu-libs > 0" \
		--depends "libpq > 0" \
		--depends "freetype > 0" \
		--depends "libpng > 0" \
		--depends "enchant > 0" \
		--depends "aspell-en > 0" \
		--depends "recode-dev > 0" \
		--depends "mariadb-client-libs > 0" \
		--depends "bash" \
		--depends "libxslt-dev" \
		--depends "gmp" \
		--depends "sqlite-dev" \
		--depends "openssl" \
		--depends "ca-certificates" \
		$(PHP71_APK_DEPENDS) \
		--force \
		--after-install /tmp/php-$(VERSION)/alpine/common/post-install \
		-a $(shell uname -m) \
		--provides "$(PKG_NAME)-cli $(PKG_NAME)-curl $(PKG_NAME)-iconv $(PKG_NAME)-calendar $(PKG_NAME)-exif $(PKG_NAME)-hash $(PKG_NAME)-sockets $(PKG_NAME)-sysvsem $(PKG_NAME)-sysvshm $(PKG_NAME)-sysvmsg $(PKG_NAME)-ctype $(PKG_NAME)-filter $(PKG_NAME)-ftp $(PKG_NAME)-fileinfo $(PKG_NAME)-gettext $(PKG_NAME)-phar $(PKG_NAME)-json"

	for ext in $(REALIZED_EXTENSIONS); do \
		/fpm/bin/fpm -s dir \
			-t apk \
			-n "$(PKG_NAME)-$$ext" \
			-v $(VERSION)-$(RELEASEVER)~$(shell uname -m) \
			-C "/tmp/php$(VERSION)-$$ext" \
			-p "$(PKG_NAME)-$$ext-$(VERSION)-$(RELEASEVER)~$(shell uname -m).apk" \
			-m "charlesportwoodii@erianna.com" \
			--license "PHP License" \
			--url https://github.com/charlesportwoodii/php-fpm-build \
			--description "PHP $$ext, $(VERSION)" \
			--vendor "Charles R. Portwood II" \
			--depends "$(PKG_NAME)-common" \
			-a $(shell uname -m) \
			--force; \
	done;

	for pkg in $(SUBPACKAGES); do \
		/fpm/bin/fpm -s dir \
			-t apk \
			-n "$(PKG_NAME)-$$pkg" \
			-v $(VERSION)-$(RELEASEVER)~$(shell uname -m) \
			-C "/tmp/php-$(VERSION)-install-$$pkg" \
			-p "$(PKG_NAME)-$$pkg-$(VERSION)-$(RELEASEVER)~$(shell uname -m).apk" \
			-m "charlesportwoodii@erianna.com" \
			--license "PHP License" \
			--url https://github.com/charlesportwoodii/php-fpm-build \
			--description "PHP $$pkg, $(VERSION)" \
			--vendor "Charles R. Portwood II" \
			--depends "$(PKG_NAME)-common" \
			--depends "openrc" \
			--depends "bash" \
			--before-install /tmp/php-$(VERSION)/alpine/$$pkg/pre-install \
			--after-install /tmp/php-$(VERSION)/alpine/$$pkg/post-install \
			--before-remove /tmp/php-$(VERSION)/alpine/$$pkg/pre-deinstall \
			-a $(shell uname -m) \
			--force; \
	done;