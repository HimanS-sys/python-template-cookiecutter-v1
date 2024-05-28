"""Module to test the generate project."""

from pathlib import Path

from tests.utils.project import generate_project


def test__can_generate_project(project_dir: Path):
    """

    execute: `cookiecutter <template directory> ...`
    """
    assert project_dir.exists()
