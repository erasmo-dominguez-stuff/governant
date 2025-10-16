###############################################
# Builder: install OPA and compile the policy #
###############################################
FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    tar \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

## TODO: Replace with Official OPA Docker Image

# Install OPA CLI (linux amd64)
RUN curl -L -o /usr/local/bin/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64 \
    && chmod +x /usr/local/bin/opa

# Copy only what's needed to compile the policy
COPY .gate/ ./.gate/
COPY scripts/ ./scripts/

# Compile policy -> outputs in .compile/<name>.wasm and .compile/<name>.tar.gz
RUN chmod +x ./scripts/compile_policy.sh \
    && ./scripts/compile_policy.sh

###############################################
# Runtime: minimal Python + compiled artifacts #
###############################################
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/opt/venv

RUN python -m venv $VIRTUAL_ENV \
    && apt-get update && apt-get install -y --no-install-recommends \
       ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="$VIRTUAL_ENV/bin:$PATH"

WORKDIR /app

# Copy app code and compiled artifacts
COPY pyproject.toml README.md ./
COPY src/ ./src/
COPY --from=builder /app/.compile/ ./.compile/

# Install app (for CLI entrypoint)
RUN pip install --no-cache-dir -e . \
    && pip install --no-cache-dir "opa-wasm[cranelift]"

# Default entrypoint to the CLI; users pass wasm path and input path
ENTRYPOINT ["python", "-m", "src.opawasm"]
CMD [".compile/github-release.wasm", "/input.json", "--entrypoint", "data.github.deploy.allow"]
