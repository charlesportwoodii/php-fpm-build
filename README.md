# Build Scripts for PHP FPM
This package contains scripts necessary to automatically build PHP FPM on your system.


## APT dependencies
```
	apt-get install make automake g++ autoconf checkinstall git build-essential libxml2-dev libcurl4-openssl-dev pkg-config libjpeg-turbo8-dev libpng12-dev libfreetype6-dev libicu-dev
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
