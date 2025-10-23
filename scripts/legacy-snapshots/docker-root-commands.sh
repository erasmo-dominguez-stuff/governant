docker build -t governant:dev -f ./docker/Dockerfile .


docker run --rm governant:dev \
  --artifact ./.compile/github_env_protect.tar.gz \
  --package github_env_protect \
  allow -i ./test-inputs/production-valid.json


docker run --rm governant:dev \
  --artifact ./.compile/github_env_protect.tar.gz \
  --package github_env_protect \
  violations -i ./test-inputs/production-invalid.json


docker run --rm governant:dev \
  --artifact ./.compile/github_env_protect.tar.gz \
  --package github_env_protect \
  decision -i ./test-inputs/production-valid.json
