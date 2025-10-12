act push \
  -W .github/workflows/opa-evaluation.yml \
  -j evaluate-policy \
  --container-architecture linux/amd64


  act push \
  -W .github/workflows/validations.yml \
  -j run-scripts \
  --container-architecture linux/amd64
  