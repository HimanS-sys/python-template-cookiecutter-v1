"""Module that runs when pytest is used."""

import sys
from pathlib import Path

THIS_DIR = Path(__file__).parent
TESTS_DIR_PARENT = (THIS_DIR / "..").resolve()

sys.path.insert(0, str(TESTS_DIR_PARENT))

pytest_plugins = ["tests_repo.fixtures.project_dir"]
