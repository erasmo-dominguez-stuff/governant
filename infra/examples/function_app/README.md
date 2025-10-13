# Example: Deploy Azure Function (Python + Wasm)

This example zips a Python application folder and deploys it to Azure Functions using the `modules/azure_function` module.

## Expected `app_path` structure
Prepare a standard Python Functions folder and include your `.wasm` (generated in `./.compile/`). For example:

```
app/
├─ host.json
├─ requirements.txt
├─ .compile/
│  └─ github-release.wasm
└─ evaluate/                 # Function name (HTTP trigger)
   ├─ __init__.py
   └─ function.json
```

- `evaluate/__init__.py` should read the HTTP request body and evaluate against the `.wasm` (using your CLI/code).
- `requirements.txt` should include any dependencies used (optionally `opa-wasm`).

## Usage (Terraform)

1. Authenticate to Azure (e.g. `az login`) or export credentials.
2. Set variables via `terraform.tfvars` or CLI.
3. Run:

```
terraform init
terraform apply -auto-approve \
  -var "name=governant-func" \
  -var "location=westeurope" \
  -var "resource_group_name=rg-governant" \
  -var "app_path=/absolute/path/to/app"
```

> Note: `app_path` must point to the directory containing `host.json` and the subfolder with the `.wasm` (e.g. `.compile/github-release.wasm`).
