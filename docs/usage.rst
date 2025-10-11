.. _usage:

Usage
=====

Basic Usage
----------

Import the package:

.. code-block:: python

    import governant

Command Line Interface
----------------------

Governant provides a command-line interface for common tasks:

.. code-block:: bash

    # Validate an environment
    governant validate development

    # Run tests
    governant test

    # Generate documentation
    governant docs

Configuration
------------

Governant can be configured using environment variables or a configuration file.

Environment Variables
~~~~~~~~~~~~~~~~~~~~

- ``GOVERNANT_ENV``: The current environment (development, staging, production)
- ``GOVERNANT_CONFIG_PATH``: Path to configuration file

Configuration File
~~~~~~~~~~~~~~~~~

Create a ``.governant.yaml`` file in your project root:

.. code-block:: yaml

    environment: development
    rules:
      require_ticket: true
      ticket_pattern: "[A-Z]+-\\d+"
      require_approvals: 1

Examples
--------

Validate Environment
~~~~~~~~~~~~~~~~~~~

.. code-block:: python

    from governant.validation import validate_environment
    import json

    with open(".gate/policy.json") as f:
        policy = json.load(f)
    
    if validate_environment("development", policy):
        print("Environment is valid!")
    else:
        print("Environment validation failed!")
