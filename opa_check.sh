opa fmt -w .gate/github_env_protect.rego
opa check .gate/github_env_protect.rego

# OPA CLI: evaluar directamente el .rego (no el bundle WASM)
echo "OPA CLI: evaluating allow con test-inputs/production-valid.json (rego)"
opa eval \
  -d .gate/github_env_protect.rego \
  --input test-inputs/production-valid.json \
  'data.github.deploy.allow' | sed -e 's/^/[OPA] /'

echo "OPA CLI: evaluating violations con test-inputs/production-invalid.json (rego)"
opa eval \
  -d .gate/github_env_protect.rego \
  --input test-inputs/production-invalid.json \
  'data.github.deploy.violations' | sed -e 's/^/[OPA] /'


./scripts/validate_schema.sh
./scripts/validate_rego.sh
./scripts//compile_policy.sh