SHELL := /bin/bash

# Dependency Versions
PCREVERSION?=8.39
OPENSSLVERSION?=1.0.2j
CURLVERSION?=7_50_2
NGHTTPVERSION?=v1.14.0
RELEASEVER?=1

# Argon2 reference library implementation
ARGON2_DIR=/tmp/libargon2

# Current Build Time
BUILDTIME=$(shell date +%s)

# Bash data
SCRIPTPATH=$(shell pwd -P)
CORES=$(shell grep -c ^processor /proc/cpuinfo)
ARCH=$(shell arch)

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

RELEASENAME=php$(major).$(minor)-fpm
PROVIDES=php$(major).$(minor)-fpm
 
build: openssl curl php

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

# Only build libargon2 for PHP 7.2+
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
	./configure CFLAGS="-I$(NGHTTP_PREFIX)/include" LDFLAGS="-L$(NGHTTP_PREFIX)/lib"\
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
		--with-sqlite3 \
		--with-pdo-sqlite \
		--with-pdo-mysql=mysqlnd \
		--with-mysqli=mysqlnd \
		--enable-mysqlnd \
		--with-pgsql \
		--with-pdo-pgsql \
		--with-readline \
		--with-jpeg-dir \
		--with-freetype-dir \
		--with-png-dir \
		--with-pic \
		--with-gettext \
		--with-iconv \
		--with-pcre-regex \
		--with-zlib \
		--with-layout=GNU \
		--with-gd \
		--with-mcrypt=shared \
		--enable-redis=shared \
		--with-mhash \
		--with-password-argon2=$(ARGON2_DIR) \
		--with-kerberos \
		--enable-exif \
		--enable-ftp \
		--enable-sockets \
		--enable-sysvsem \
		--enable-sysvshm \
		--enable-sysvmsg \
		--enable-hash \
		--enable-filter \
		--enable-shmop \
		--enable-calendar \
		--enable-pdo \
		--enable-xml=static \
		--enable-xmlreader=static \
		--enable-json \
		--enable-fpm \
		--enable-mbstring \
		--enable-inline-optimization \
		--enable-pcntl \
		--enable-mbregex \
		--enable-mbregex-backtrack \
		--enable-zip \
		--enable-opcache \
		--enable-opcache-file \
		--enable-huge-code-pages \
		--enable-soap \
		--enable-bcmath \
		--enable-phar=static \
		--enable-intl=static && \
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

	# Export the timezone as UTC 
	echo "date.timezone=UTC" >> /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/conf.d/UTC-timezone.ini

	# Output modules that are available as shared extensions
	mkdir -p /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available
	echo "extension=redis.so" > /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available/redis.ini
	echo "extension=mcrypt.so" > /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available/mcrypt.ini
	echo "zend_extension=opcache.so" > /tmp/php-$(VERSION)-install/usr/local/etc/php/$(major).$(minor)/mods-available/opache.ini

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
	cp $(SCRIPTPATH)/debian/init-php-fpm /tmp/php-$(VERSION)-install/usr/local/etc/init.d/php-fpm-$(VERSION)
	sed -i s/VERSION/$(major).$(minor)/g /tmp/php-$(VERSION)-install/usr/local/etc/init.d/php-fpm-$(VERSION)

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

fpm_debian: pre_package
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
		--deb-systemd-restart-after-upgrade \
		--template-scripts \
		--force \
		--no-deb-auto-config-files \
		--before-install /tmp/php-$(VERSION)/debian/preinstall-pak \
		--after-install /tmp/php-$(VERSION)/debian/postinstall-pak \
		--before-remove /tmp/php-$(VERSION)/debian/preremove-pak 
		
fpm_rpm: pre_package
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
		--rpm-digest sha384 \
		--rpm-compression gzip \
		--template-scripts \
		--force \
		--before-install /tmp/php-$(VERSION)/rpm/preinstall \
		--after-install /tmp/php-$(VERSION)/rpm/postinstall \
		--before-remove /tmp/php-$(VERSION)/rpm/preremove 
