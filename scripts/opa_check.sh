opa fmt -w ../.gate/github-release.rego
opa check ../.gate/github-release.rego
./validate_schema.sh
./validate_rego.sh
./compile_policy.sh
