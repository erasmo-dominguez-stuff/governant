opa fmt -w .gate/github-release.rego
opa check .gate/github-release.rego

# OPA CLI: evaluar directamente el .rego (no el bundle WASM)
note "OPA CLI: evaluating allow con test-inputs/production-valid.json (rego)"
opa eval \
  -d .gate/github-release.rego \
  --input test-inputs/production-valid.json \
  'data.github.deploy.allow' | sed -e 's/^/[OPA] /'

note "OPA CLI: evaluating violations con test-inputs/production-invalid.json (rego)"
opa eval \
  -d .gate/github-release.rego \
  --input test-inputs/production-invalid.json \
  'data.github.deploy.violations' | sed -e 's/^/[OPA] /'


./scripts/validate_schema.sh
./scripts/validate_rego.sh
./scripts//compile_policy.sh