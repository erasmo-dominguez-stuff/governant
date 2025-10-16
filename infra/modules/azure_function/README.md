# Azure Function (Python) Module

Despliega una Azure Function (Linux, v4, Python) y publica un paquete ZIP (código Python + Wasm) usando WEBSITE_RUN_FROM_PACKAGE.

## Entradas
- `name` (string): Nombre base del Function App.
- `location` (string): Región, p.ej. `westeurope`.
- `resource_group_name` (string): Resource Group existente.
- `zip_package_path` (string): Ruta local al ZIP a publicar.
- `python_version` (string, opcional): `3.11` por defecto.
- `app_settings` (map(string), opcional): App settings extra.
- `tags` (map(string), opcional).

## Salidas
- `function_app_id` (string)
- `function_app_name` (string)
- `default_hostname` (string)
- `run_from_package_url` (string)

## Notas
- El módulo crea una Storage Account para alojar el ZIP y configura `WEBSITE_RUN_FROM_PACKAGE` con una URL SAS.
- Asegúrate de que el ZIP contiene una Azure Function Python válida (estructura de carpetas `host.json`, `requirements.txt`, `/<function>/function.json`, etc.) y tu `.wasm` en la ruta esperada por tu código.
