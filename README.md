# Build Scripts for PHP FPM

This repository provides an opinionated build of PHP FPM, and enables you to quickly build and package modern versions of PHP.

Packages are published to https://apt.erianna.com. See https://www.erianna.com/packages for a list of updated packages.

### Why should I use this package?

This package provides a opinionated build for PHP + FPM. The primary differentiators between this package and other PPA's are:

- __Cross Platform Consistency__: PHP is built exactly the same for Ubuntu, Alpine Linux, and RHEL. Ensuring that your local, testing, and production PHP builds are _always_ the same.
- __Extensible__: Shared PHP modules are used to allow fine-grain control over which extensions and development tools you wish to have installed. Common modules not distributed with `php-src`, such as PHP Redis, Libsodium, Argon2, and others are bundled as external dependencies
- __Strong Security__: OpenSSL and libcurl are statically compiled into the final binary. Regular updates of point releases ensure bugs of security issues with bundled libraries are promptly updated. Deprecated modules such as _mcrypt_ are disabled by default on versions of PHP that support it. Strong security defaults are bundled with PHP.ini.
- __Publicly auditable builds__: All packages and images are built in public GitHub Actions runs before publishing

## Releasing

Releases are cut from the GitHub Actions **release** workflow.

1. Open Actions → release → Run workflow.
2. Enter the version in `MAJOR.MINOR.PATCH-REVISION` form, for example `8.5.10-1`.
3. Leave `dry_run` unchecked for a real release.

The workflow creates the tag on the default branch and a GitHub release,
compiles and packages every distro that supports that PHP version on native
amd64 and arm64 runners, uploads the packages to Spaces, triggers Drone to
refresh the apt and Alpine indexes, then builds and pushes the multi-arch
Docker images.

Which distro builds which PHP version is defined in one place,
`ci/build_matrix.py`.

If a single distro fails, use **Re-run failed jobs**. Only the failed job
repeats; artifacts from the jobs that already succeeded are in Spaces.

Drone is retained for one thing only: the apt and Alpine index refresh,
which runs against a host reachable solely through Teleport. That pipeline
is triggered by the release workflow through the Drone API and does not run
on tag pushes.

## Building & Packaging
> Tested on Ubuntu LTS releases (x86_64 and ARM64), Alpine Linux, and RHEL.

The preferred way of building PHP is to use build and package them within Docker, and then to install PHP from the packages it provides. This allows you to build PHP in an environment isolated from your own, and allows you to install PHP through your package manager, rather than through source. This approach requires both `Docker` and `docker-compose` to be installed. (see https://docs.docker.com/).

1. Install Docker (https://docs.docker.com/engine/installation/)
2. Install Docker Compose 1.15.0+ (https://docs.docker.com/compose/install/)
3. Build PHP-FPM by running `docker-compose`, and specifying the platform you want to build for
    ```
    VERSION=<PHP_VERSION> RELEASEVER=1 docker-compose run <trusty|xenial|bionic|centos7|rhel7|alpine3.10>
    ```

> Note that the `<PHP_VERSION>` corresponds too the git tag of `php/php-src`, sans `PHP`.
