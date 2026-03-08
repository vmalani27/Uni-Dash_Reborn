# Stage 1: Build Rust-based dependencies
FROM rust:1.75-slim-bookworm AS rust-builder
WORKDIR /usr/src/app
# This ensures we have the right headers for python-based builds
RUN apt-get update && apt-get install -y python3 python3-pip python3-venv pkg-config libssl-dev

# Stage 2: Python Builder
FROM python:3.10-slim-bookworm AS builder
WORKDIR /backend

# Copy Rust binaries/toolchain from the rust-builder if needed, 
# but usually, it's easier to just install build-essentials here 
# and let pip handle the heavy lifting.
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    pkg-config \
    libssl-dev \
    libffi-dev \
    libblas-dev \
    liblapack-dev \
    curl

# Fix for ARM: Install Rust safely via the official method OR use the pre-built env
# To ensure the right architecture, we force the rustup detection:
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"

COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir --user -r requirements.txt

# Final stage: Minimal runtime
FROM python:3.10-slim-bookworm
WORKDIR /backend

# Install runtime-only libs
RUN apt-get update && apt-get install -y \
    libssl3 \
    libblas3 \
    liblapack3 \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

COPY app ./app
COPY .env ./.env
COPY credentials.json ./app/core/credentials.json

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]