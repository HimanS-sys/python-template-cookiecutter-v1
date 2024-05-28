"""Module containing tests for Makefile functionality."""

import subprocess
from pathlib import Path


def test__linting_passes(project_dir: Path):
    subprocess.run(
        [
            "make",
            "lint-ci",
        ],
        cwd=project_dir,
        check=True,
    )


def test__tests_passes(project_dir: Path):
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

"""
Setup:
1. generate a project using cookiecutter
2. Create a virtual environment and install project dependencies.

Tests:
3. run tests
4. run linting

Cleanup/Teardown:
6. Remove the virtual environment
7. Remove generated project
"""
