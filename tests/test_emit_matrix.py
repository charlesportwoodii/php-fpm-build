import json
import os
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run(version, dry_run, tmp_path):
    output = tmp_path / "gh_output"
    output.write_text("")
    env = dict(os.environ, GITHUB_OUTPUT=str(output), PYTHONPATH=REPO_ROOT)
    # Invoked as a module, not a path. Running `python ci/emit_matrix.py`
    # puts ci/ on sys.path instead of the repo root, so `from ci.build_matrix
    # import ...` would fail.
    subprocess.run(
        [sys.executable, "-m", "ci.emit_matrix", "--version", version]
        + (["--dry-run"] if dry_run else []),
        cwd=REPO_ROOT,
        env=env,
        check=True,
    )
    result = {}
    for line in output.read_text().splitlines():
        key, _, value = line.partition("=")
        result[key] = value
    return result


def test_emits_version_fields(tmp_path):
    out = run("8.5.9-1", False, tmp_path)
    assert out["version"] == "8.5.9"
    assert out["releasever"] == "1"
    assert out["short_version"] == "8.5"


def test_emits_parseable_matrix(tmp_path):
    out = run("8.5.9-1", False, tmp_path)
    matrix = json.loads(out["matrix"])
    assert len(matrix["include"]) == 4


def test_real_release_has_empty_s3_prefix(tmp_path):
    assert run("8.5.9-1", False, tmp_path)["s3_prefix"] == ""


def test_dry_run_uses_staging_prefix(tmp_path):
    assert run("8.5.9-1", True, tmp_path)["s3_prefix"] == ".staging/8.5.9-1/"


def test_reports_dockerfile_presence(tmp_path):
    assert run("8.5.9-1", False, tmp_path)["has_dockerfile"] == "true"


def test_matrix_json_is_single_line(tmp_path):
    """GITHUB_OUTPUT is line-based; embedded newlines would corrupt it."""
    out = run("8.5.9-1", False, tmp_path)
    assert "\n" not in out["matrix"]
