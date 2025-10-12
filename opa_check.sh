opa fmt -w .gate/github-release.rego
opa check .gate/github-release.rego
./scripts/validate_schema.sh
./scripts/validate_rego.sh
./scripts/compile_policy.sh