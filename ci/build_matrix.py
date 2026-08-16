"""Single source of truth for which distro builds which PHP version.

Replaces the sixteen hand-maintained `when.ref.exclude` lists that used to
live in .drone.yml. Adding a PHP version or a distro is a change to DISTROS
and nothing else.
"""

import os

RUNNERS = {"amd64": "ubuntu-24.04", "arm64": "ubuntu-24.04-arm"}

# Alpine names the architectures differently from Docker/GitHub.
ALPINE_ARCH = {"amd64": "x86_64", "arm64": "aarch64"}

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DISTROS = [
    {
        "name": "focal",
        "packaging": "debian",
        "image": "charlesportwoodii/ubuntu:20.04-build",
        "build_os": "Ubuntu",
        "build_os_version": "20.04",
        "php_versions": ["7.4", "8.0", "8.1", "8.2", "8.3"],
        "extra_apt_packages": {
            "amd64": "bison libbison-dev libffi-dev",
            "arm64": "bison libbison-dev libffi-dev libpsl-dev",
        },
        "remove_apt_packages": "",
        "alpine_version": "",
    },
    {
        "name": "jammy",
        "packaging": "debian",
        "image": "charlesportwoodii/ubuntu:22.04-build",
        "build_os": "Ubuntu",
        "build_os_version": "22.04",
        "php_versions": ["8.1", "8.2", "8.3"],
        "extra_apt_packages": {
            "amd64": "bison libbison-dev libffi-dev",
            "arm64": "bison libbison-dev libffi-dev",
        },
        "remove_apt_packages": "",
        "alpine_version": "",
    },
    {
        "name": "noble",
        "packaging": "debian",
        "image": "charlesportwoodii/ubuntu:24.04-build",
        "build_os": "Ubuntu",
        "build_os_version": "24.04",
        "php_versions": ["8.4", "8.5"],
        "extra_apt_packages": {
            "amd64": "bison libbison-dev libffi-dev libpsl-dev",
            "arm64": "bison libbison-dev libffi-dev libpsl-dev",
        },
        "remove_apt_packages": "libbrotli",
        "alpine_version": "",
    },
    {
        # Normalised: the old arm64 rule also allowed 7.2 while amd64 did not.
        # PHP 7.2 is end-of-life and has no Dockerfile, so both arches now
        # build 8.0 and later.
        "name": "alpine3.14",
        "packaging": "alpine",
        "image": "charlesportwoodii/alpine:3.14-build",
        "build_os": "Alpine",
        "build_os_version": "3.14",
        "php_versions": ["8.0", "8.1", "8.2", "8.3", "8.4", "8.5"],
        "extra_apt_packages": {"amd64": "", "arm64": ""},
        "remove_apt_packages": "",
        "alpine_version": "3140",
    },
]

ARCHES = ["amd64", "arm64"]


def distros_for(short_version):
    """Distros that build the given MAJOR.MINOR, in table order."""
    return [d for d in DISTROS if short_version in d["php_versions"]]


def _artifact_dir(distro, arch):
    if distro["packaging"] == "alpine":
        return "build/alpine/v{}/main/{}".format(
            distro["build_os_version"], ALPINE_ARCH[arch]
        )
    return "build/deb/{}".format(distro["name"])


def _job(distro, arch):
    artifact_dir = _artifact_dir(distro, arch)
    return {
        "name": distro["name"],
        "arch": arch,
        "runner": RUNNERS[arch],
        "image": distro["image"],
        "packaging": distro["packaging"],
        "build_os": distro["build_os"],
        "build_os_version": distro["build_os_version"],
        "extra_apt_packages": distro["extra_apt_packages"][arch],
        "remove_apt_packages": distro["remove_apt_packages"],
        "alpine_version": distro["alpine_version"],
        "artifact_dir": artifact_dir,
        # Bucket keys drop the leading "build/" so the layout matches what
        # `aws s3 cp ./build/ s3://$BUCKET --recursive` produced under Drone.
        "s3_key": artifact_dir[len("build/"):],
    }


def build_matrix(short_version):
    """Matrix for the compile/package jobs: one entry per distro per arch."""
    return {
        "include": [
            _job(distro, arch)
            for distro in distros_for(short_version)
            for arch in ARCHES
        ]
    }


def docker_matrix(short_version):
    """Matrix for the image jobs. Always both arches when an image is built."""
    del short_version  # image builds are not distro-scoped
    return {"include": [{"arch": arch, "runner": RUNNERS[arch]} for arch in ARCHES]}


def has_dockerfile(short_version):
    return os.path.isfile(
        os.path.join(REPO_ROOT, "Dockerfile.php{}".format(short_version))
    )
