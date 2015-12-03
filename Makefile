SCRIPTPATH=`pwd -P`
PCREVERSION=8.37
OPENSSLVERSION=1.0.2e
CURLVERSION=7_46_0
NGHTTPVERSION=v1.5.0
CORES=$(grep -c ^processor /proc/cpuinfo)

# Prefixes and constants
OPENSSL_PATH=/opt/openssl
NGHTTP_PREFIX=/opt/nghttp2
CURL_PREFIX=/opt/curl

RELEASE=$(lsb_release --codename | cut -f2)

version=$(echo $(VERSION) | grep -o [^-]*$)
major=$(echo $(version) | cut -d. -f1)
minor=$(echo $(version) | cut -d. -f2)
micro=$(echo $(version) | cut -d. -f3)

build: build_openssl build_nghttp2 build_curl build_php

build_openssl:
		echo $(OPENSSL_PATH)
		rm -rf /tmp/openssl*
		cd /tmp && \
		wget https://www.openssl.org/source/openssl-$(OPENSSLVERSION).tar.gz && \
		tar -xf openssl-$(OPENSSLVERSION).tar.gz && \
		cd openssl-$(OPENSSLVERSION) && \
		git clone https://github.com/cloudflare/sslconfig && \
		cp sslconfig/patches/openssl__chacha20_poly1305_cf.patch . && \
		patch -p1 < openssl__chacha20_poly1305_cf.patch && \
		./config --prefix=$(OPENSSL_PATH) no-shared enable-ec_nistp_64_gcc_128 enable-tlsext && \
		make depend && \
		make -j$(CORES) && \
		make all && \
		make install_sw && \
		cd $(OPENSSL_PATH) && \
		ln -s lib lib64

build_nghttp2:
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
		ln -s lib lib64

build_curl:
	echo "build_curl"

build_php:
	echo "build_php"

install:
	echo "Install"
