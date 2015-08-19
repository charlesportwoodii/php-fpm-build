# Build Scripts for PHP FPM
This package contains scripts necessary to automatically build PHP FPM on your system.


## Other dependencies

bison (not 3.0 from apt)

wget http://launchpadlibrarian.net/140087283/libbison-dev_2.7.1.dfsg-1_amd64.deb
wget http://launchpadlibrarian.net/140087282/bison_2.7.1.dfsg-1_amd64.deb
dpkg -i libbison-dev_2.7.1.dfsg-1_amd64.deb
dpkg -i bison_2.7.1.dfsg-1_amd64.deb

## APT dependencies
```
	apt-get install make automake g++ autoconf checkinstall git build-essential libxml2-dev libcurl4-openssl-dev pkg-config libjpeg-turbo8-dev libpng12-dev libfreetype6-dev libicu-dev libmcrypt4 libmcrypt-dev libreadline6-dev
```

## Building

```
	cd /tmp
	git clone https://github.com/charlesportwoodii/php-fpm-build
	cd php-fpm-build
	chmod +x build.sh
	sudo ./build.sh <version>
```

Where ```<version>``` corresponds to the php build version you want build
