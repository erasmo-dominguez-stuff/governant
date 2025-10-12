opa fmt -w .gate/github-release.rego
opa check .gate/github-release.rego
./scripts/compile_policy.sh