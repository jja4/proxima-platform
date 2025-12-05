FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install uv (fast Python package installer) and place it on the global PATH
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && install -m 755 /root/.local/bin/uv /usr/local/bin/uv
ENV PATH="/root/.local/bin:$PATH"

# Install Python and build dependencies
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-venv \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Google Cloud SDK (non-interactive)
# Adds the official Google Cloud apt repository and installs `google-cloud-cli`.
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates gnupg curl lsb-release \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
       > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl -sSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && apt-get update && apt-get install -y google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# UV will install dependencies on postCreateCommand

# Auto-activate the project virtualenv for the vscode user if present
RUN echo '\n# Auto-activate project venv if available\nif [ -f /workspace/.venv/bin/activate ]; then\n  . /workspace/.venv/bin/activate\nfi\n' >> /home/vscode/.zshrc
