FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install uv (fast Python package installer)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:$PATH"

# Install Python and build dependencies
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-venv \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# UV will install dependencies on postCreateCommand
