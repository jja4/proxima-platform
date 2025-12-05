FROM python:3.10-slim

# Small, native Ray image for local dev; builds for host arch (arm64 on Apple Silicon, amd64 on PCs)
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ca-certificates \
    git \
    gcc \
    g++ \
    libffi-dev \
    libssl-dev \
    procps \
    net-tools \
  && rm -rf /var/lib/apt/lists/*

# Install Ray (match compose tag; uses host arch wheels when available)
# Pin click below 8.1.7 to avoid Ray CLI deepcopy/Sentinel crash, then install Ray
RUN pip install --no-cache-dir "click<8.1.7" \
 && pip install --no-cache-dir "ray[default]==2.9.3"

WORKDIR /workspace

CMD ["/bin/sh", "-c"]
