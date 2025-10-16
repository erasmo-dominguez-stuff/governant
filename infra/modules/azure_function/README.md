# Azure Function (Python) Module

Deploys an Azure Function (Linux, v4, Python) and publishes a ZIP package (Python code + Wasm) using WEBSITE_RUN_FROM_PACKAGE.

## Inputs
- `name` (string): Base name for the Function App.
- `location` (string): Region, e.g. `westeurope`.
- `resource_group_name` (string): Existing Resource Group name.
- `zip_package_path` (string): Local path to the ZIP to publish.
- `python_version` (string, optional): Default `3.11`.
- `app_settings` (map(string), optional): Extra app settings.
- `tags` (map(string), optional).

## Outputs
- `function_app_id` (string)
- `function_app_name` (string)
- `default_hostname` (string)
- `run_from_package_url` (string)

## Notes
- The module creates a Storage Account to host the ZIP and sets `WEBSITE_RUN_FROM_PACKAGE` with a SAS URL.
- Ensure the ZIP contains a valid Azure Function Python layout (folders like `host.json`, `requirements.txt`, `/<function>/function.json`, etc.) and your `.wasm` in the path expected by your code.
