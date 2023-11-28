SHELL := /bin/bash

include .envs
export

# Zend Maintainer Debug Mode
ENABLE_MAINTAINER_MODE?=false

# Extra packages that certain distributions may require
EXTRA_APT_PACKAGES?=
EXTRA_RPM_PACKAGES?=
REMOVE_RPM_PACKAGES?=

BUILD_OS?=
BUILD_IMAGE?=
BUILD_OS_VERSION?=

# Alpine Linux version, only used for Alpine builds
ALPINE_VERSION?=

# Dependency Versions
CURLVERSION?=8_4_0
NGHTTPVERSION?=1.57.0
RELEASEVER?=1

# Library versions
ARGON2VERSION?=20190702
LIBSODIUMVERSION?=1.0.19-RELEASE

# External extension versions
REDISEXTVERSION?=6.0.1
IGBINARYVERISON?=3.2.14
ARGON2EXTVERSION?=1.2.1
LIBSODIUMEXTVERSION?=2.0.22

SHARED_EXTENSIONS := pdo_sqlite pdo_pgsql pdo_mysql pgsql mysqlnd mysqli sqlite3 xml mbstring zip intl redis mcrypt xsl bz2 gd enchant ldap pspell recode sodium gmp soap igbinary
SHARED_ZEND_EXTENSIONS := opcache
REALIZED_EXTENSIONS := opcache sqlite3 mysql pgsql xml mbstring zip intl redis mcrypt xsl bz2 gd enchant ldap pspell recode sodium gmp soap igbinary

# Reference library implementations
ARGON2_DIR=/tmp/libargon2
LIBSODIUM_DIR=/tmp/libsodium

# Current Build Time
BUILDTIME=$(shell date +%s)

# Bash data
SCRIPTPATH=$(shell pwd -P)
CORES?=$(shell grep -c ^processor /proc/cpuinfo)
ARCH=$(shell arch)

# Opcache Jit isn't yet working in <= PHP 8.0.x (yet).
ifeq ($(shell arch),aarch64)
IS_ARM=1
ARM_FLAGS=--disable-opcache-jit
endif

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

OPENSSLVERSION?=3.2.0

# Ubuntu dependencies
ifeq ($(shell lsb_release --codename | cut -f2),xenial)
LIBICU=libicu55
LIBMYSQLCLIENT=libmysqlclient20
LIBWEBP_DEBIAN=libwebp5
LIBPNG=libpng12-0
LIBONIG_DEBIAN=libonig2
LIBCURL_DEBIAN=libcurl3
LIBZIP_DEBIAN=libzip4
LIBFFI_DEBIAN=libffi6
else ifeq ($(shell lsb_release --codename | cut -f2),bionic)
LIBICU=libicu60
LIBMYSQLCLIENT=libmysqlclient20
LIBWEBP_DEBIAN=libwebp6
LIBPNG=libpng16-16
LIBONIG_DEBIAN=libonig4
LIBCURL_DEBIAN=libcurl4
LIBZIP_DEBIAN=libzip4
LIBFFI_DEBIAN=libffi6
LIBENCHANT_DEBIAN=libenchant1c2a
else ifeq ($(shell lsb_release --codename | cut -f2),focal)
LIBICU=libicu66
LIBMYSQLCLIENT=libmysqlclient21
LIBWEBP_DEBIAN=libwebp6
LIBPNG=libpng16-16
LIBONIG_DEBIAN=libonig5
LIBCURL_DEBIAN=libcurl4
LIBZIP_DEBIAN=libzip5
LIBFFI_DEBIAN=libffi7
LIBENCHANT_DEBIAN=libenchant1c2a
else ifeq ($(shell lsb_release --codename | cut -f2),jammy)
LIBICU=libicu70
LIBMYSQLCLIENT=libmysqlclient21
LIBWEBP_DEBIAN=libwebp7
LIBPNG=libpng16-16
LIBONIG_DEBIAN=libonig5
LIBCURL_DEBIAN=libcurl4
LIBZIP_DEBIAN=libzip4
LIBFFI_DEBIAN=libffi8
LIBENCHANT_DEBIAN=libenchant-2-2
endif

ifneq ($(BUILD_OS),"Alpine")
TARGET=$(shell arch)-unknown-linux-musl
else
TARGET=$(shell arch)-linux-gnu
endif

ifeq ($(shell if [[ "$(ALPINE_VERSION)" -ge 380 ]]; then echo 0; else echo 1; fi;),0)
ifeq ($(shell if [[ "$(ALPINE_VERSION)" -ge 3140 ]]; then echo 0; else echo 1; fi;),0)
ALPINE_DEPENDS=--depends "mariadb-connector-c > 0" --depends "mariadb-connector-c-dev > 0" --depends "enchant2 > 0" --depends "openldap" > 0 --depends "icu" > 0  --depends "openldap-dev" > 0 --depends "icu-dev" > 0
else
ALPINE_DEPENDS=--depends "mariadb-connector-c > 0" --depends "mariadb-connector-c-dev > 0" --depends "enchant > 0"
endif
else
ALPINE_DEPENDS=--depends "mariadb-client-libs > 0"
endif

# Argon2 is only in PHP 7.2-7.4 7.4 bundles sodium
ifeq ($(shell if [[ "$(TESTVERSION)" -ge "72" ]] && [[ "$(TESTVERSION)" -lt "74" ]]; then echo 0; else echo 1; fi;), 0)
PHP72ARGS="--with-password-argon2=$(ARGON2_DIR)"
endif

# Set PHP_CONFIG_FLAGS for different PHP version
ifeq ($(shell if [[ "$(TESTVERSION)" -lt "74" ]]; then echo 0; else echo 1; fi;), 0)
PHP_CFLAGS="-I$(NGHTTP_PREFIX)/include -I$(CURL_PREFIX)/include -I$(OPENSSL_PATH)/include"
PHP_LDFLAGS="-L$(NGHTTP_PREFIX)/lib -L$(CURL_PREFIX)/lib -L$(OPENSSL_PATH)/lib"
PHP_CONFIG_FLAGS= LIBS="-lpthread" CFLAGS=$(PHP_CFLAGS) LDFLAGS=$(PHP_LDFLAGS)
PHP72_DEB_DEPENDS=--depends "librecode0 > 0" --depends "$(LIBZIP_DEBIAN) >= 1.1.0"
PHP72_RPM_DEPENDS=--depends "librecode > 0"
PHP72_APK_DEPENDS= --depends "recode-dev > 0"
endif

# Adjust gd configuration for 7.4 vs 7.3--
ifeq ($(shell if [[ "$(TESTVERSION)" -ge "74" ]]; then echo 0; else echo 1; fi;), 0)
PHP74ARGS=--enable-gd=shared --with-ffi=shared --with-freetype --with-jpeg --with-webp --with-xpm --with-libedit --with-openssl --with-curl --with-zip
PHP74_APK_DEPENDS=--depends "libedit" --depends "libgpg-error" --depends "libgcrypt" --depends "oniguruma" --depends "libwebp" --depends "libxpm" --depends "libffi"
PHP74_DEB_DEPENDS=--depends "$(LIBONIG_DEBIAN)" --depends "libedit2" --depends "libgcrypt20" --depends "libgpg-error0" --depends "$(LIBWEBP_DEBIAN)" --depends "libxpm4" --depends "$(LIBCURL_DEBIAN)" --depends "$(LIBFFI_DEBIAN) > 3.1"
PHP74_RPM_DEPENDS=--depends "oniguruma" --depends "libedit" --depends "libgcrypt" --depends "libgpg-error" --depends "libwebp" --depends "libXpm" --depends "libffi > 3.1"
# Rconfigure PKG_CONFIG_PATH environment variable
PKG_CONFIG_PATH_BASE=$(shell pkg-config --variable pc_path pkg-config)
USE_PKG_CONFIG=PKG_CONFIG_PATH=$(OPENSSL_PATH)/lib/pkgconfig:$(NGHTTP_PREFIX)/lib/pkgconfig:$(CURL_PREFIX)/lib/pkgconfig:/usr/lib/pkgconfig/enchant-2.pc
else
PHP74ARGS=--with-gd=shared --with-jpeg-dir --with-freetype-dir --with-png-dir --with-recode=shared --with-readline --with-openssl=$(OPENSSL_PATH) --with-curl=$(CURL_PREFIX) --enable-zip=shared --enable-opcache-file --enable-mbregex-backtrack --with-pcre-regex --enable-hash
endif

ifeq ($(ENABLE_MAINTAINER_MODE), true)
MAINTAINER_FLAGS=--enable-debug --enable-maintainer-zts
else
MAINTAINER_FLAGS=--disable-debug
endif

SQLITEARGS=--with-sqlite3=shared,/usr
PDOSQLITEARGS=--with-pdo-sqlite=shared,/usr

RELEASENAME=$(PKG_NAME)-common
PROVIDES=$(PKG_NAME)-common

define install_apt_package
	apt install $(1) -y;
endef

define install_apt_package_from_curl
	curl -sqL $(1) -o package.deb;
	dpkg -i package.deb;
	rm package.deb;
endef

define install_rpm_package_from_curl
	curl -sqL $(1) -o package.rpm;
	rpm -if --replacefiles package.rpm;
	rm package.rpm;
endef

build: pre_install info openssl curl libraries php

pre_install:
ifneq ($(EXTRA_DEB_PACKAGES),)
	$(foreach package, $(EXTRA_DEB_PACKAGES), $(call install_apt_package_from_curl, $(package)))
endif

ifneq ($(EXTRA_APT_PACKAGES),)
ifeq ($(shell if [[ "$(TESTVERSION)" -ge "74" ]]; then echo 0; else echo 1; fi;), 0)
	apt update -qq;
	$(foreach package, $(EXTRA_APT_PACKAGES), $(call install_apt_package, $(package)))
endif
endif

ifneq ($(REMOVE_RPM_PACKAGES),)
	yum remove -y $(REMOVE_RPM_PACKAGES)
endif

ifneq ($(EXTRA_RPM_PACKAGES),)
	$(foreach package, $(EXTRA_RPM_PACKAGES), $(call install_rpm_package_from_curl, $(package)))
endif

info:
	@echo "Building $(VERSION)-$(RELEASEVER) ($(major).$(minor).$(micro))"
	@echo "Native Compiler Optimizations"
	gcc -march=native -E -v - </dev/null 2>&1 | grep cc1
	echo | gcc -dM -E - -march=native

clean_dist:
	rm -rf *.deb
	rm -rf *.apk
	rm -rf *.rpm

determine_extensions:
ifeq ($(shell if [[ "$(TESTVERSION)" -ge "72" ]]; then echo 0; else echo 1; fi;), 0)
	$(eval SHARED_EXTENSIONS:= $(shell echo $(SHARED_EXTENSIONS) | sed s/mcrypt//g))
	$(eval REALIZED_EXTENSIONS:= $(shell echo $(REALIZED_EXTENSIONS) | sed s/mcrypt//g))
endif

ifeq ($(shell if [[ "$(TESTVERSION)" -ge "74" ]]; then echo 0; else echo 1; fi;), 0)
	$(eval SHARED_EXTENSIONS:= $(shell echo $(SHARED_EXTENSIONS) | sed s/recode//g))
	$(eval REALIZED_EXTENSIONS:= $(shell echo $(REALIZED_EXTENSIONS) | sed s/recode//g))

	$(eval SHARED_EXTENSIONS:= $(shell echo $(SHARED_EXTENSIONS) | sed s/zip//g))
	$(eval REALIZED_EXTENSIONS:= $(shell echo $(REALIZED_EXTENSIONS) | sed s/zip//g))
endif

	@echo $(SHARED_EXTENSIONS)
	@echo $(REALIZED_EXTENSIONS)

openssl:
	echo $(OPENSSL_PATH)
	rm -rf /tmp/openssl*
	cd /tmp && \
	curl https://www.openssl.org/source/openssl-$(OPENSSLVERSION).tar.gz --output openssl-$(OPENSSLVERSION).tar.gz && \
	tar -xf openssl-$(OPENSSLVERSION).tar.gz && \
	cd /tmp/openssl-$(OPENSSLVERSION) && \
	./config --prefix=$(OPENSSL_PATH) --release no-shared no-ssl3 enable-tls1_3 no-threads && \
	make depend && \
	make && \
	make all && \
	make install_sw && \
	cd $(OPENSSL_PATH) && \
	ln -fs lib lib64

nghttp2:
	echo $(NGHTTP_PREFIX)
	rm -rf /tmp/nghttp2*
	cd /tmp && \
	curl -L https://github.com/nghttp2/nghttp2/releases/download/v$(NGHTTPVERSION)/nghttp2-$(NGHTTPVERSION).tar.gz --output nghttp2-$(NGHTTPVERSION).tar.gz && \
	tar -xf nghttp2-$(NGHTTPVERSION).tar.gz && \
	cd nghttp2-$(NGHTTPVERSION) && \
	./configure \
		--prefix=$(NGHTTP_PREFIX) \
		--enable-static=yes \
		--enable-shared=no \
		--disable-python-bindings && \
	make && \
	make install && \
	cd $(NGHTTP_PREFIX) && \
	ln -fs lib lib64

curl: nghttp2
	echo $(CURL_PREFIX)
	rm -rf /tmp/curl*
	cd /tmp && \
	curl -L https://github.com/curl/curl/releases/download/curl-$(CURLVERSION)/curl-$(shell echo $(CURLVERSION) | tr '_' '.').tar.gz --output curl-$(shell echo $(CURLVERSION) | tr '_' '.').tar.gz && \
	tar -xf curl-$(shell echo $(CURLVERSION) | tr '_' '.').tar.gz && \
	cd curl-$(shell echo $(CURLVERSION) | tr '_' '.') && \
	LIBS="-ldl" env PKG_CONFIG_PATH=$(OPENSSL_PATH)/lib/pkgconfig:$(NGHTTP_PREFIX)/lib/pkgconfig \
	./configure  \
		--prefix=$(CURL_PREFIX) \
		--with-ssl \
		--disable-shared \
		--disable-ldap \
		--disable-threaded-resolver \
		--disable-pthreads \
		--with-libssl-prefix=$(OPENSSL_PATH) \
		--with-nghttp2=$(NGHTTP_PREFIX) \
		--disable-ldaps && \
	make && \
	make install && \
	cd $(CURL_PREFIX) && \
	ln -fs lib lib64

ifeq ($(shell if [[ "$(TESTVERSION)" -lt "74" ]]; then echo 0; else echo 1; fi;), 0)
	rm $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc
else
# Curl's generated pkgconfig doesn't contain the right linkage to nghttp2
#$(eval _LN=$(shell cat $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc | grep -n "Libs:" | cut -f1 -d:))
#@echo "Changing line: $(_LN)"
#sed '$(_LN)s/$$/ -L\/opt\/nghttp2\/lib -lnghttp2 /' $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc > $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc.tmp
# Fix this to be dynamic later
	sed '39s/$$/ -L\/opt\/nghttp2\/lib -lnghttp2 -ldl/' $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc > $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc.tmp
	mv $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc.tmp $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc

ifeq ($(ALPINE_VERSION),3110)
	sed '39s/$$/ -L\/opt\/nghttp2\/lib -lbrotlidec/' $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc > $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc.tmp
	mv $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc.tmp $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc
endif

ifeq ($(BUILD_OS),Ubuntu)
	sed '39s/$$/ -lbrotlidec -L\/opt\/openssl\/lib -lssl -lcrypto -ldl/' $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc > $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc.tmp
	mv $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc.tmp $(CURL_PREFIX)/lib/pkgconfig/libcurl.pc
endif
endif

# Only build libargon2 for PHP 7.0+
libargon2:
ifeq ($(shell if [[ "$(TESTVERSION)" -ge "70" ]] && [[ "$(TESTVERSION)" -lt "74" ]]; then echo 0; else echo 1; fi;), 0)
	rm -rf $(ARGON2_DIR)

	cd /tmp && \
	git clone https://github.com/P-H-C/phc-winner-argon2 -b $(ARGON2VERSION) libargon2 && \
	cd $(ARGON2_DIR) && \
	CFLAGS="-fPIC" make OPTTARGET=i686

	cd $(ARGON2_DIR) && \
	ln -s . lib && \
	ln -s . lib64 && \
	ln -s . libs

	rm -rf $(ARGON2_DIR)/libargon2.so*
endif

libsodium:
	rm -rf /tmp/libsodium*

	cd /tmp && \
	curl -L https://github.com/jedisct1/libsodium/archive/$(LIBSODIUMVERSION).tar.gz --output $(LIBSODIUMVERSION).tar.gz
	tar -xf /tmp/$(LIBSODIUMVERSION).tar.gz && \
	cp -R libsodium-$(LIBSODIUMVERSION) $(LIBSODIUM_DIR) && \
	cd $(LIBSODIUM_DIR) && \
	rm -rf $(LIBSODIUM_DIR)/lib && \
	./configure --disable-shared --disable-pie && \
	CFLAGS="-fPIC" make install

libraries: libargon2 libsodium

php: determine_extensions
	rm -rf /tmp/php-$(VERSION)
	echo Building for PHP $(VERSION)

	cd /tmp && \
	curl -L https://github.com/php/php-src/archive/php-$(VERSION).tar.gz --output php-$(VERSION).tar.gz && \
	tar -xf php-$(VERSION).tar.gz && \
	mv php-src-php-$(VERSION) php-$(VERSION)

	cd /tmp/php-$(VERSION)/ext && git clone --depth 1 -b $(REDISEXTVERSION) https://github.com/phpredis/phpredis redis

	cd /tmp/php-$(VERSION)/ext && git clone --depth 1 -b $(IGBINARYVERISON) https://github.com/igbinary/igbinary igbinary

	# Need to patch igbinary 3.0.0 due to $phpincludedir not being defined
	# BUG: https://github.com/igbinary/igbinary/issues/50
	sed -i s/\\$phpincludedir/\\/tmp\\/php-$(major).$(minor).$(micro)/g /tmp/php-$(VERSION)/ext/igbinary/config.m4

ifeq ($(shell if [[ "$(TESTVERSION)" -ge "70" ]] && [[ "$(TESTVERSION)" -lt "74" ]]; then echo 0; else echo 1; fi;), 0)
	# Only download the Argon2 PHP extension for PHP 7.0+
	cd /tmp/php-$(VERSION)/ext && git clone --depth 1  -b $(ARGON2EXTVERSION) https://github.com/charlesportwoodii/php-argon2-ext argon2

	mkdir -p /tmp/php-$(VERSION)/ext/argon2
	cp -R $(ARGON2_DIR)/*  /tmp/php-$(VERSION)/ext/argon2/
endif

# Libsodium is bundled with PHP in 7.2
ifeq ($(shell if [[ "$(TESTVERSION)" -lt "72" ]]; then echo 0; else echo 1; fi;), 0)
	cd /tmp/php-$(VERSION)/ext && git clone --depth 1 -b $(LIBSODIUMEXTVERSION) https://github.com/jedisct1/libsodium-php sodium
endif

	# Build
	cd /tmp/php-$(VERSION) && \
	./buildconf --force && \
	$(USE_PKG_CONFIG) ./configure $(PHP_CONFIG_FLAGS) \
		--with-libdir=lib64 \
		--build=$(TARGET) \
		--host=$(TARGET) \
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
		--libexecdir=${prefix}/lib/php/$(major).$(minor) \
		--with-config-file-path=/etc/php/$(major).$(minor) \
		--with-config-file-scan-dir=/etc/php/$(major).$(minor)/conf.d \
		--with-fpm-user=www-data \
		--without-pear \
		--without-gdbm \
		--disable-short-tags \
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
		--with-gmp=shared \
		--with-pic \
		--with-gettext \
		--with-iconv \
		--with-pcre-jit \
		--with-zlib \
		--with-layout=GNU \
    	--enable-gd-jis-conv \
		--with-mhash \
		--enable-fileinfo \
		--enable-igbinary=shared \
		--enable-redis=shared \
		--enable-redis-igbinary \
		--enable-exif \
		--enable-ctype \
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
		--enable-intl=shared \
		--enable-soap=shared \
		--enable-json \
		--enable-fpm \
		--enable-inline-optimization \
		--enable-pcntl \
		--enable-mbregex \
		--enable-opcache \
		--enable-huge-code-pages \
		--enable-bcmath \
		--enable-phar=static \
		--disable-phpdbg \
		$(ARM_FLAGS) \
		$(MAINTAINER_FLAGS) \
		$(SQLITEARGS) \
		$(PDOSQLITEARGS) \
		$(PHP72ARGS) \
		$(PHP74ARGS) && \
		make

pear:
	rm -rf /tmp/php-pear
	rm -rf /tmp/php-pear-install
	mkdir -p /tmp/php-pear
	mkdir -p /tmp/php-pear-install
	curl -q https://pear.php.net/install-pear-nozlib.phar --output /tmp/php-pear/install-pear-nozlib.phar
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

pre_package: determine_extensions
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
	rm -rf /tmp/php-$(VERSION)-install-fpm/usr/bin/
	rm -rf /tmp/php-$(VERSION)-install-cgi/usr/sbin/
	rm -rf /tmp/php-$(VERSION)-install-dev/usr/sbin/
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

	find  /tmp/php-$(VERSION)-install-fpm -type d -empty -delete

	# CGI
	mv /tmp/php-$(VERSION)-install/usr/bin/php-cgi$(major).$(minor) /tmp/php-$(VERSION)-install-cgi/usr/bin/
	mv /tmp/php-$(VERSION)-install/share/man/php/$(major).$(minor)/man1/php-cgi* /tmp/php-$(VERSION)-install-cgi/share/man/php/$(major).$(minor)/man1
	find  /tmp/php-$(VERSION)-install-cgi -type d -empty -delete

	# DEV
	mv /tmp/php-$(VERSION)-install/usr/bin/phpize$(major).$(minor) /tmp/php-$(VERSION)-install-dev/usr/bin/
	mv /tmp/php-$(VERSION)-install/usr/bin/php-config$(major).$(minor) /tmp/php-$(VERSION)-install-dev/usr/bin/

	mv /tmp/php-$(VERSION)-install/share/man/php/$(major).$(minor)/man1/phpize$(major).$(minor).1 /tmp/php-$(VERSION)-install-dev/share/man/php/$(major).$(minor)/man1
	mv /tmp/php-$(VERSION)-install/share/man/php/$(major).$(minor)/man1/php-config$(major).$(minor).1 /tmp/php-$(VERSION)-install-dev/share/man/php/$(major).$(minor)/man1
	mkdir -p /tmp/php-$(VERSION)-install-dev/lib/php/$(major).$(minor)/build
	mv /tmp/php-$(VERSION)-install/lib/php/$(major).$(minor)/build/* /tmp/php-$(VERSION)-install-dev/lib/php/$(major).$(minor)/build/

	find  /tmp/php-$(VERSION)-install-dev -type d -empty -delete

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
	rm -rf /tmp/php-$(VERSION)-install/usr/sbin
	rm -rf /tmp/php-$(VERSION)-install/usr/bin/phar
	rm -rf /tmp/php-$(VERSION)-install/usr/bin/phar.phar
	rm -rf /tmp/php-$(VERSION)-install/share/man/php/$(major).$(minor)/phar.1
	rm -rf /tmp/php-$(VERSION)-install/share/man/php/$(major).$(minor)/phar.phar.1

	# Make log and runtime directory
	mkdir -p /tmp/php-$(VERSION)-install/var/log/php/$(major).$(minor)
	mkdir -p /tmp/php-$(VERSION)-install/var/run/php/$(major).$(minor)

	find  /tmp/php-$(VERSION)-install -type d -empty -delete

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
		mv /tmp/php-$(VERSION)/modules/$$ext.* /tmp/php$(VERSION)-$$ext/lib/php/$(major).$(minor)/$(PHPAPI)/; \
		mv /tmp/php-$(VERSION)-install/include/php/$(major).$(minor)/php/ext/$$ext/* /tmp/php$(VERSION)-$$ext/include/php/$(major).$(minor)/php/ext/$$ext/; \
		rm -rf /tmp/php-$(VERSION)-install/include/php/$(major).$(minor)/php/ext/$$ext/; \
	done;

	for ext in $(SHARED_ZEND_EXTENSIONS); do \
		rm -rf /tmp/php$(VERSION)-$$ext; \
		mkdir -p /tmp/php$(VERSION)-$$ext/usr/local/etc/php/$(major).$(minor)/mods-available; \
		mkdir -p /tmp/php$(VERSION)-$$ext/lib/php/$(major).$(minor)/$(PHPAPI)/; \
		mkdir -p /tmp/php$(VERSION)-$$ext/include/php/$(major).$(minor)/php/ext/$$ext/; \
		echo "zend_extension=$$ext.so" > /tmp/php$(VERSION)-$$ext/usr/local/etc/php/$(major).$(minor)/mods-available/$$ext.ini; \
		mv /tmp/php-$(VERSION)/modules/$$ext.* /tmp/php$(VERSION)-$$ext/lib/php/$(major).$(minor)/$(PHPAPI)/; \
		mv /tmp/php-$(VERSION)-install/include/php/$(major).$(minor)/php/ext/$$ext/* /tmp/php$(VERSION)-$$ext/include/php/$(major).$(minor)/php/ext/$$ext/; \
		rm -rf /tmp/php-$(VERSION)-install/include/php/$(major).$(minor)/php/ext/$$ext/; \
	done;

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
		--depends "$(LIBPNG) > 0" \
		--depends "$(LIBENCHANT_DEBIAN) > 0" \
		--depends "aspell-en > 0" \
		--depends "librecode0 > 0" \
		--depends "libxslt1.1 > 0" \
		--depends "$(LIBMYSQLCLIENT) > 0" \
		--depends "libbrotli" \
		--depends "openssl" \
		--depends "libxslt1.1" \
		$(PHP72_DEB_DEPENDS) \
		$(PHP74_DEB_DEPENDS) \
		--deb-systemd-restart-after-upgrade \
		--template-scripts \
		--force \
		--no-deb-auto-config-files \
		--after-install /tmp/php-$(VERSION)/debian/common/postinstall-pak \
		--before-remove /tmp/php-$(VERSION)/debian/common/preremove-pak \
		--deb-compression=gz \
		--provides "php-cli (= $(VERSION))"

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

fpm_alpine: pre_package pre_package_ext
	fpm -s dir \
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
		--depends "libintl > 0" \
		--depends "aspell-en > 0" \
		--depends "bash" \
		--depends "libxslt-dev" \
		--depends "gmp" \
		--depends "sqlite-dev" \
		--depends "openssl" \
		--depends "ca-certificates" \
		--depends "libbrotli" \
		--depends "libzip > 1.1.0" \
		$(ALPINE_DEPENDS) \
		$(PHP72_APK_DEPENDS) \
		$(PHP74_APK_DEPENDS) \
		--force \
		--after-install /tmp/php-$(VERSION)/alpine/common/post-install \
		-a $(shell uname -m) \
		--provides "php-cli"

	for ext in $(REALIZED_EXTENSIONS); do \
		fpm -s dir \
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
		fpm -s dir \
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
