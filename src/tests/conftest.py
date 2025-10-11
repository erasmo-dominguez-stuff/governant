"""Pytest configuration and fixtures."""
import os
import pytest

# Obtener la ruta absoluta al directorio de test-inputs
TEST_INPUTS_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'scripts',
    'test-inputs'
)

@pytest.fixture
def test_inputs_dir():
    """Fixture que retorna la ruta al directorio de test-inputs."""
    return TEST_INPUTS_DIR

@pytest.fixture
def example_json_path(test_inputs_dir):
    """Fixture que retorna la ruta al archivo example.json."""
    return os.path.join(test_inputs_dir, 'example.json')
