.. _contributing:

Contributing
============

We welcome contributions! Here's how you can help:

Development Setup
----------------

1. Fork the repository
2. Clone your fork:

   .. code-block:: bash

       git clone https://github.com/yourusername/governant.git
       cd governant

3. Set up a virtual environment:

   .. code-block:: bash

       python -m venv venv
       source venv/bin/activate  # On Windows: venv\Scripts\activate

4. Install development dependencies:

   .. code-block:: bash

       pip install -e .[dev]
       pre-commit install
       pre-commit install --hook-type pre-push

Running Tests
-------------

Run all tests:

.. code-block:: bash

    pytest

Run with coverage:

.. code-block:: bash

    pytest --cov=governant --cov-report=term-missing

Code Style
----------

We use:

- **Black** for code formatting
- **isort** for import sorting
- **flake8** for linting
- **mypy** for type checking

These are automatically checked by pre-commit hooks.

Documentation
-------------

Build documentation locally:

.. code-block:: bash

    cd docs
    make html
    open _build/html/index.html

Or run with auto-reload:

.. code-block:: bash

    cd docs
    make autoserve

Pull Request Process
--------------------

1. Create a feature/fix branch from `develop`
2. Add tests for your changes
3. Update documentation if needed
4. Run all tests and pre-commit hooks
5. Submit a pull request to the `develop` branch

Code of Conduct
---------------

Please note that this project is released with a Code of Conduct. By participating in this project you agree to abide by its terms.
