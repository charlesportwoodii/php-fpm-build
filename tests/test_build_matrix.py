import pytest

from ci.build_matrix import (
    DISTROS,
    build_matrix,
    distros_for,
    docker_matrix,
    has_dockerfile,
)


def names(short_version):
    return sorted(d["name"] for d in distros_for(short_version))


def test_php_85_builds_only_noble_and_alpine():
    assert names("8.5") == ["alpine3.14", "noble"]


def test_php_83_builds_focal_jammy_and_alpine():
    assert names("8.3") == ["alpine3.14", "focal", "jammy"]


def test_php_74_builds_only_focal():
    assert names("7.4") == ["focal"]


def test_alpine_does_not_build_php_72_on_either_arch():
    assert "alpine3.14" not in names("7.2")


def test_unknown_version_builds_nothing():
    assert names("9.9") == []


def test_focal_extra_apt_packages_differ_by_arch():
    focal = next(d for d in DISTROS if d["name"] == "focal")
    assert focal["extra_apt_packages"]["amd64"] == "bison libbison-dev libffi-dev"
    assert (
        focal["extra_apt_packages"]["arm64"]
        == "bison libbison-dev libffi-dev libpsl-dev"
    )


def test_build_matrix_emits_one_job_per_distro_per_arch():
    jobs = build_matrix("8.5")["include"]
    assert len(jobs) == 4
    assert sorted((j["name"], j["arch"]) for j in jobs) == [
        ("alpine3.14", "amd64"),
        ("alpine3.14", "arm64"),
        ("noble", "amd64"),
        ("noble", "arm64"),
    ]


def test_build_matrix_job_carries_every_field_the_workflow_needs():
    job = next(
        j for j in build_matrix("8.5")["include"]
        if j["name"] == "noble" and j["arch"] == "arm64"
    )
    assert job["runner"] == "ubuntu-24.04-arm"
    assert job["image"] == "charlesportwoodii/ubuntu:24.04-build"
    assert job["packaging"] == "debian"
    assert job["build_os"] == "Ubuntu"
    assert job["build_os_version"] == "24.04"
    assert job["extra_apt_packages"] == "bison libbison-dev libffi-dev libpsl-dev"
    assert job["remove_apt_packages"] == "libbrotli"
    assert job["alpine_version"] == ""
    assert job["artifact_dir"] == "build/deb/noble"
    assert job["s3_key"] == "deb/noble"


def test_alpine_job_uses_arch_specific_artifact_path():
    jobs = build_matrix("8.5")["include"]
    amd = next(j for j in jobs if j["name"] == "alpine3.14" and j["arch"] == "amd64")
    arm = next(j for j in jobs if j["name"] == "alpine3.14" and j["arch"] == "arm64")
    assert amd["artifact_dir"] == "build/alpine/v3.14/main/x86_64"
    assert amd["s3_key"] == "alpine/v3.14/main/x86_64"
    assert arm["artifact_dir"] == "build/alpine/v3.14/main/aarch64"
    assert arm["s3_key"] == "alpine/v3.14/main/aarch64"
    assert amd["alpine_version"] == "3140"
    assert amd["packaging"] == "alpine"


def test_amd64_runner_label():
    job = build_matrix("8.5")["include"][0]
    assert job["runner"] in ("ubuntu-24.04", "ubuntu-24.04-arm")


def test_docker_matrix_is_both_arches():
    assert docker_matrix("8.5") == {
        "include": [
            {"arch": "amd64", "runner": "ubuntu-24.04"},
            {"arch": "arm64", "runner": "ubuntu-24.04-arm"},
        ]
    }


@pytest.mark.parametrize(
    "short_version", ["7.3", "7.4", "8.0", "8.1", "8.2", "8.3", "8.4", "8.5"]
)
def test_dockerfile_exists_for_supported_versions(short_version):
    assert has_dockerfile(short_version) is True


def test_no_dockerfile_for_unsupported_version():
    assert has_dockerfile("7.2") is False
