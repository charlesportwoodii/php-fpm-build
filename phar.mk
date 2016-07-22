SHELL := /bin/bash

phar:
    rm -rf /tmp/php-phar
    cd /tmp/php-phar && \
    curl -O https://pear.php.net/go-pear.phar