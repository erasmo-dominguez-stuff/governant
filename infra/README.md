# Infra

Terraform infrastructure to deploy an Azure Function that runs the policy evaluator (Python + Wasm).

- Module: `infra/modules/azure_function/`
- Usage example: `infra/examples/function_app/`

General requirements:
- Terraform >= 1.5
- Provider `azurerm` >= 3.x
- Azure access (via `az login`) or environment variables for authentication
- A ZIP package ready to publish (your Python code and the `.wasm` in paths your function expects)

