FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OPA_VERSION=0.58.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    git \
    vim \
    less \
    && rm -rf /var/lib/apt/lists/*

# Install Open Policy Agent
RUN curl -L -o opa https://github.com/open-policy-agent/opa/releases/download/v${OPA_VERSION}/opa_linux_amd64 \
    && chmod +x opa \
    && mv opa /usr/local/bin/

# Install additional tools
RUN curl -L -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && chmod +x /usr/local/bin/yq

# Create working directory
WORKDIR /workspace

# Copy policy files
COPY policies/ ./policies/
COPY test-inputs/ ./test-inputs/
COPY test-policy.sh ./test-policy.sh
COPY test-advanced.sh ./test-advanced.sh
COPY README.md ./README.md

# Make scripts executable
RUN chmod +x test-policy.sh test-advanced.sh

# Create a non-root user
RUN useradd -m -s /bin/bash opa-user \
    && chown -R opa-user:opa-user /workspace

USER opa-user

# Set default command
CMD ["/bin/bash"]

# Expose port for OPA server (if needed)
EXPOSE 8181
