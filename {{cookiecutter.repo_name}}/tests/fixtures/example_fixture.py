"""Module containg project directory fixture implementation."""

from uuid import uuid4

import pytest
from tests.consts import PROJECT_DIR


@pytest.fixture(scope="session")
def test_session_id() -> str:
    """Create a unique test session id for test."""
    test_session_id = str(PROJECT_DIR.name) + str(uuid4())[:6]
    return test_session_id
