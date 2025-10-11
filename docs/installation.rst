.. _installation:

Installation
============

Using pip
---------

.. code-block:: bash

    pip install governant

From source
-----------

1. Clone the repository:

   .. code-block:: bash

       git clone https://github.com/yourusername/governant.git
       cd governant

2. Install in development mode:

   .. code-block:: bash

       pip install -e .[dev]

3. Install pre-commit hooks:

   .. code-block:: bash

       pre-commit install
       pre-commit install --hook-type pre-push

Dependencies
------------

- Python 3.8+
- Dependencies are listed in ``pyproject.toml``
