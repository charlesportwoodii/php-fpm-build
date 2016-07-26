# Build Scripts for PHP FPM

This packages helps you quick and easily build any modern version of PHP (5.5, 5.6, 7.0, etc...) on your system. This package provides many common and vital packages for running modern PHP on your system. If this package doesn't help you, there's a bug in this package. 

## Debian Builds
Tested on Ubuntu 12.04, Ubuntu 14.04, Ubuntu 16.04

### Dependencies

1. Install Bison 2.7

```bash
wget http://launchpadlibrarian.net/140087283/libbison-dev_2.7.1.dfsg-1_amd64.deb
wget http://launchpadlibrarian.net/140087282/bison_2.7.1.dfsg-1_amd64.deb
sudo dpkg -i libbison-dev_2.7.1.dfsg-1_amd64.deb
sudo dpkg -i bison_2.7.1.dfsg-1_amd64.deb
```

2. Add the Postgresql 9.5+ development libraries

```bash
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install postgresql-contrib-9.5 postgresql-server-dev-9.5
```

3. Install all other APT repositories

```bash
apt-get install make automake g++ autoconf checkinstall git build-essential libxml2-dev pkg-config libjpeg-turbo8-dev libpng12-dev libfreetype6-dev libicu-dev libmcrypt4 libmcrypt-dev libreadline6-dev libtool
```

## RPM Builds
Tested on CentOS7.2

### Dependencies

1. Install Repo dependencies for CentOS/Fedora/RedHat

```bash
sudo yum install wget
wget http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum install rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm 
sudo yum install epel-release-latest-7.noarch.rpm
sudo yum update
sudo yum upgrade
```

2. Install PostgreSQL dependencies

```bash
wget https://download.postgresql.org/pub/repos/yum/9.5/redhat/rhel-7-x86_64/pgdg-centos95-9.5-2.noarch.rpm
sudo yum install pgdg-centos95-9.5-2.noarch.rpm
```

2. Install PHP FPM library dependencies

```bash
sudo yum install make automake autoconf g++ build-essential glib2-devel glibc-devel git libmcrypt-devel libmcrypt gcc libtool libxml2-devel libicu-devel gcc-c++ bison libpng12-devel libjpeg-turbo readline-devel postgresql95-devel freetype-devel libjpeg-turbo-devel postgresql-devel
sudo yum group install "Development Tools"
```

## Building

PHP can be built via `make` by running the following steps:

```bash
# Build OpenSSL and cURL with sudo so they can be installed to their runtime directories
sudo make openssl
sudo make curl

# Do not build PHP with sudo
make build VERSION=<PHP_VERSION>
```

## Packaging

Packaging is performed through [FPM](https://github.com/jordansissel/fpm)

```bash
gem install fpm
```

Once FPM is installed, you can package your application either for debian or rpm by running the following commands, respectively

```bash
make fpm_debian VERSION=<PHP_VERSION>
make fpm_rpm VERSION=<PHP_VERSION>
```
