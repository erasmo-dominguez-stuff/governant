###############################################
# Stage: obtain official OPA binary (from upstream image)
###############################################
FROM openpolicyagent/opa:latest AS opa


###############################################
# Builder (optional): compile the policy with your script
# If you already have the compiled bundle in the repo (.compile/*),
# this stage will just copy it forward. If you need to compile here,
# ensure the compile script and sources exist.
###############################################
FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl tar \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the opa binary from the official image so the builder has the same version
COPY --from=opa /opa /usr/local/bin/opa
RUN chmod +x /usr/local/bin/opa || true

# ---- OPTION A: compile inside the image (requires your sources & script) ----
# COPY .gate/ ./.gate/
# COPY scripts/ ./scripts/
# RUN chmod +x ./scripts/compile_github_env_protect_policy.sh \
#  && ./scripts/compile_github_env_protect_policy.sh

# ---- OPTION B: reuse precompiled artifacts from repo (default) ----
# If you already have the compiled bundle locally, copy it.
COPY .compile/ ./.compile/

# Also copy inputs for quick local tests (optional)
COPY test-inputs/ ./test-inputs/


###############################################
# Runtime: minimal Python runtime with CLI + opa
###############################################
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/opt/venv

# Create non-root user
RUN useradd -m -u 10001 appuser

# Minimal deps + venv
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && python -m venv $VIRTUAL_ENV

ENV PATH="$VIRTUAL_ENV/bin:$PATH"

WORKDIR /app

# Copy your project (only what's needed to install governant)
COPY pyproject.toml README.md ./
COPY src/ ./src/

# Copy compiled policy bundle & sample inputs from builder
COPY --from=builder /app/.compile/ ./.compile/
COPY --from=builder /app/test-inputs/ ./test-inputs/

# Copy opa binary from official image (align runtime with builder)
COPY --from=opa /opa /usr/local/bin/opa
RUN chmod +x /usr/local/bin/opa || true

# Install the app and runtime dependency
RUN pip install --no-cache-dir -e . \
 && pip install --no-cache-dir "opa-wasm[cranelift]"

# Drop privileges
USER appuser

# Default workdir is /app. ENTRYPOINT uses the REAL package/CLI.
ENTRYPOINT ["python", "-m", "governant.cli"]
# Default command: show CLI version when no arguments are provided.
# You can still pass commands like `allow -i /input.json` when running the container.
CMD ["version"]
