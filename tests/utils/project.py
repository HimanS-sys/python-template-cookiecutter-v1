"""Module to store test fixture function."""

import json
import subprocess
from copy import deepcopy
from pathlib import Path
from typing import Dict

from tests.consts import PROJECT_DIR


def initialize_git_repo(repo_dir: Path):
    """Run a test that initialize GIT repo."""
    subprocess.run(
        ["git", "init"],
        cwd=repo_dir,
        check=True,
    )
    subprocess.run(
        ["git", "branch", "-M", "main"],
        cwd=repo_dir,
        check=True,
    )
    subprocess.run(
        ["git", "add", "--all"],
        cwd=repo_dir,
        check=True,
    )
    subprocess.run(
        ["git", "commit", "-m", "'feat: initial commit by pytest'"],
        cwd=repo_dir,
        check=True,
    )


def generate_project(template_values: Dict[str, str], test_session_id: str):
    """Generate project for test purpose."""
    template_values: Dict[str, str] = deepcopy(template_values)
    cookiecutter_config = {"default_context": template_values}
    cookiecutter_config_fpath = PROJECT_DIR / f"tests/cookiecutter-{test_session_id}.json"
    cookiecutter_config_fpath.write_text(json.dumps(cookiecutter_config))

    cmd = [
        "cookiecutter",
        str(PROJECT_DIR),
        "--output-dir",
        str(PROJECT_DIR / "sample"),
        "--no-input",
        "--config-file",
        str(cookiecutter_config_fpath),
        "--verbose",
    ]
    # cmd_joined = " ".join(cmd)
    # print(f"\n\n\ncmd:\n{cmd_joined}\n\n\n")
    subprocess.run(cmd, check=True)

    generated_repo_dir: Path = PROJECT_DIR / "sample" / template_values["repo_name"]
    return generated_repo_dir