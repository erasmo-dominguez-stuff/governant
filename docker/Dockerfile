###############################################
# Stage: obtain official OPA binary (from upstream image)
###############################################
FROM openpolicyagent/opa:latest AS opa


###############################################
# Builder: compile the policy using Python image
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

# Copy the opa binary from the official image so the builder has the same version
COPY --from=opa /opa /usr/local/bin/opa
RUN chmod +x /usr/local/bin/opa || true

# Copy only what's needed to compile the policy
COPY .gate/ ./.gate/
COPY scripts/ ./scripts/

# Ensure compile script is executable and run it
RUN chmod +x ./scripts/compile_github_env_protect_policy.sh \
    && ./scripts/compile_github_env_protect_policy.sh


###############################################
# Runtime: minimal Python runtime with CLI + opa
###############################################
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/opt/venv

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && python -m venv $VIRTUAL_ENV

ENV PATH="$VIRTUAL_ENV/bin:$PATH"

WORKDIR /app

# Copy the Python package and compiled policy bundle from builder
COPY pyproject.toml README.md ./
COPY src/ ./src/
COPY --from=builder /app/.compile/ ./.compile/

# Copy opa binary from official image (keeps runtime aligned with builder)
COPY --from=opa /opa /usr/local/bin/opa
RUN chmod +x /usr/local/bin/opa || true

# Install the app and runtime dependency
RUN pip install --no-cache-dir -e . \
    && pip install --no-cache-dir "opa-wasm[cranelift]"

# Expose a small helper: run the Python CLI as the container entrypoint.
# Usage examples:
#  docker run --rm -v $(pwd)/input.json:/input.json image:tag --artifact ./.compile/github_env_protect.tar.gz allow -i /input.json --output bool
ENTRYPOINT ["python", "-m", "opawasm.cli"]
CMD ["--artifact", ".compile/github_env_protect.tar.gz", "allow", "-i", "/input.json", "--output", "bool"]
