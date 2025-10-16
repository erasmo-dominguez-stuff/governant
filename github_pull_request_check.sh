#bin/bash
opa fmt -w .gate/github_pull_request.rego
opa check .gate/github_pull_request.rego

# case OK (pr_validation without repo env required)
opa eval --format pretty \
  --data .gate/github_pull_request.rego \
  --input test-inputs/pr_valid.json \
  "data.github.pullrequest.allow"

# Show violations
opa eval --format pretty \
  --data .gate/github_pull_request.rego \
  --input test-inputs/pr_valid.json \
  "data.github.pullrequest.violations"

# CASE FAIL (prod requires a repo env and its not present)
opa eval --format pretty \
  --data .gate/github_pull_request.rego \
  --input test-inputs/pr_no_valid.json \
  "data.github.pullrequest.allow"

# unit testing 
opa test .gate/ --ignore '*.json'
