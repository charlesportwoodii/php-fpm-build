# Build Scripts for PHP FPM

[![TravisCI](https://img.shields.io/travis/charlesportwoodii/php-fpm-build.svg?style=flat-square&branch=master "TravisCI")](https://travis-ci.org/charlesportwoodii/php-fpm-build)

This repository provides an opinionated build of PHP FPM, and enables you to quickly build and package modern versions of PHP.

### Why should I use this package?

This package provides a opinionated build for PHP FPM. The primary differentiators between this package and other PPA's are:

- Almost every module is statically compiled to reduce external dependencies
- The latest versions of OpenSSL and libcurl are statically compiled into PHP from source
- Common modules not distributed with `php-src`, such as Redis, are bundled as external dependencies
- Certain modules, such as mcrypt, are not enabled by default, but must be manually enabled via ini file
- Publicly auditable builds via TravisCI (https://travis-ci.org/charlesportwoodii/php-fpm-build/branches)

If you're looking to _just_ use PHP FPM, and want a single binary compiled with the most common extensions, compiled with the latest versions of OpenSSL and cURL, this package is for you. If you'd prefer to have a more modular build, ppa:ondrej/php might be preferable.

## Building & Packaging
> Tested on Ubuntu 14.04, Ubuntu 16.04, CentOS7, RHEL, and Alpine 3.6

The preferred way of building PHP is to use build and package them within Docker, and then to install PHP from the packages it provides. This allows you to build PHP in an environment isolated from your own, and allows you to install PHP through your package manager, rather than through source. This approach requires both `Docker` and `docker-compose` to be installed. (see https://docs.docker.com/).

1. Install Docker (https://docs.docker.com/engine/installation/)
2. Install Docker Composer 1.8.0+ (https://docs.docker.com/compose/install/)
3. Build PHP-FPM by running `docker-compose`, and specifying the platform you want to build for
	```
	VERSION=<PHP_VERSION> RELEASEVER=1 docker-compose run <trusty|xenial|centos7|rhel7|alpine3.6>
	```

> Note all packages are build for x86_64. x86, armv6l, and armv7l images are not supported.
