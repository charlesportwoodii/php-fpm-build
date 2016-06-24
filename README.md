# Build Scripts for PHP FPM
This package contains scripts necessary to automatically build PHP-FPM on your system.


## Debian Builds
Tested on Ubuntu 12.04, Ubuntu 14.04, Ubuntu 16.04

### Dependencies

1. Install Bison 2.7
```
wget http://launchpadlibrarian.net/140087283/libbison-dev_2.7.1.dfsg-1_amd64.deb
wget http://launchpadlibrarian.net/140087282/bison_2.7.1.dfsg-1_amd64.deb
sudo dpkg -i libbison-dev_2.7.1.dfsg-1_amd64.deb
sudo dpkg -i bison_2.7.1.dfsg-1_amd64.deb
```
2. Add the Postgresql 9.5+ development libraries
```
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install postgresql-contrib-9.5 postgresql-server-dev-9.5
```
3. Install all other APT repositories
```
	apt-get install make automake g++ autoconf checkinstall git build-essential libxml2-dev pkg-config libjpeg-turbo8-dev libpng12-dev libfreetype6-dev libicu-dev libmcrypt4 libmcrypt-dev libreadline6-dev
```

## RedHat Builds
Untested on CentOS7.2

### Dependencies

1. Install Repo dependencies for CentOS7 (http://repoforge.org/use/)
```
sudo yum install wget
wget http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum install rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm 
sudo yum install epel-release-latest-7.noarch.rpm
sudo yum update
sudo yum upgrade
```
2. Install PHP FPM library dependencies
```
sudo yum install make automake autoconf g++ build-essential glib2-devel.x86_64 glibc-devel.x86_64 git libmcrypt-devel.x86_64 libmcrypt.x86_64 gcc libtool.x86_64 bison.x86_64 libxml2-devel.x86_64 libicu-devel.x86_64 gcc-c++.x86_64
sudo yum group install "Development Tools"
```

## Building

PHP can be built via ```make``` by running the following steps:

```
make build VERSION=<PHP_VERSION>
```

## Packaging

### FPM

### Checkinstall

If you want to create a ```checkinstall``` debian package, run the following command

```
make package VERSION=<PHP_VERSION>
```

Several variables are exposed for you to modify if you wish to install PHP with a different set of depenencies. You may specify these as ```make``` arguements

```
PCREVERSION
OPENSSLVERSION
CURLVERSION
NGHTTPVERSION
RELEASEVER
```

> WARNING: running the make command will install PHP onto your system, and install several depenencies into ```/opt```. It is recommended to only run this package only on a build server rather than your personal machine. If you _just_ want to install PHP via apt, be sure to check out https://deb.erianna.com.
