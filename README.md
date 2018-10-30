# Build Scripts for PHP FPM

[![TravisCI](https://img.shields.io/travis/charlesportwoodii/php-fpm-build.svg?style=flat-square&branch=master "TravisCI")](https://travis-ci.com/charlesportwoodii/php-fpm-build)

This repository provides an opinionated build of PHP FPM, and enables you to quickly build and package modern versions of PHP.

### Why should I use this package?

This package provides a opinionated build for PHP + FPM. The primary differentiators between this package and other PPA's are:

- __Cross Platform Consistency__: PHP is built exactly the same for Trusty, Xenial, RHEL7, CentOS7, and Alpine 3.6-3.8. Ensure that your local, testing, and production PHP builds are _always_ the same.
- __Extensible__: Shared PHP modules are used to allow fine-grain control over which extensions and development tools you wish to have installed. Common modules not distributed with `php-src`, such as PHP Redis, Libsodium, Argon2, and others are bundled as external dependencies
- __Strong Security__: OpenSSL and libcurl are statically compiled into the final binary. Regular updates of point releases ensure bugs of security issues with bundled libraries are promptly updated. Deprecated modules such as _mcrypt_ are disabled by default on versions of PHP that support it. Strong security defaults are bundled with PHP.ini.
- __Publicly auditable builds__: All builds are built on TravisCI before publishing (https://travis-ci.org/charlesportwoodii/php-fpm-build/branches)

If you're looking to _just_ use PHP FPM, and want a single binary compiled with the most common extensions, compiled with the latest versions of OpenSSL and cURL, this package is for you. If you'd prefer to have a more modular build, ppa:ondrej/php might be preferable.

## Building & Packaging
> Tested on Ubuntu 14.04, Ubuntu 16.04, CentOS7, RHEL, and Alpine 3.6

The preferred way of building PHP is to use build and package them within Docker, and then to install PHP from the packages it provides. This allows you to build PHP in an environment isolated from your own, and allows you to install PHP through your package manager, rather than through source. This approach requires both `Docker` and `docker-compose` to be installed. (see https://docs.docker.com/).

1. Install Docker (https://docs.docker.com/engine/installation/)
2. Install Docker Composer 1.15.0+ (https://docs.docker.com/compose/install/)
3. Build PHP-FPM by running `docker-compose`, and specifying the platform you want to build for
	```
	VERSION=<PHP_VERSION> RELEASEVER=1 docker-compose run <trusty|xenial|centos7|rhel7|alpine3.6>
	```

> Note all packages are build for x86_64. x86, armv6l, and armv7l images are not supported.
> Note that the `<PHP_VERSION>` corresponds too the git tag of `php/php-src`, sans `PHP`.
