"""Module containing tests for Makefile functionality."""

import subprocess
from pathlib import Path


def test__linting_passes(project_dir: Path):
    """Run a test for linting."""
    subprocess.run(
        [
            "make",
            "lint-ci",
        ],
        cwd=project_dir,
        check=True,
    )


def test__tests_passes(project_dir: Path):
    """Ran a test to cjeck if tests pass."""
    subprocess.run(
        [
            "make",
            "install",
        ],
        cwd=project_dir,
        check=True,
    )
    subprocess.run(
        [
            "make",
            "test-wheel-locally",
        ],
        cwd=project_dir,
        check=True,
    )
