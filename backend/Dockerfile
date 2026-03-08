# Builder stage: Install Rust and build Python dependencies
FROM python:3.10-slim AS builder

WORKDIR /backend

# Install build-essential and curl for Rust toolchain
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    libssl-dev \
    libffi-dev \
    libblas-dev \
    liblapack-dev \
    pkg-config \
    curl \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && rm -rf /var/lib/apt/lists/*

# Set Rust on PATH for the builder stage
ENV PATH="/root/.cargo/bin:${PATH}"

COPY requirements.txt .

RUN pip install --upgrade pip && \
    pip install --no-cache-dir --user -r requirements.txt

# Final stage: Minimal runtime environment
FROM python:3.10-slim

WORKDIR /backend

# Install only binary runtime dependencies (libssl, libpq for psycopg2, etc.)
RUN apt-get update && apt-get install -y \
    libssl3 \
    libffi8 \
    libblas3 \
    liblapack3 \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy installed packages from builder
COPY --from=builder /root/.local /root/.local

# Ensure the installed packages are on the PATH
ENV PATH=/root/.local/bin:$PATH

# Copy the app directory
COPY app ./app

# Copy environment variables and credentials into the image
COPY .env ./.env
COPY credentials.json ./app/core/credentials.json

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
