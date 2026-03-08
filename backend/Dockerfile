# Stage 1: Build Rust-based dependencies
FROM --platform=linux/arm/v7 python:3.10-slim-bookworm AS builder

WORKDIR /backend

# Standard build tools
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    libssl-dev \
    libffi-dev \
    libblas-dev \
    liblapack-dev \
    pkg-config \
    curl

# CRITICAL FIX: Tell the Rust installer to use the 32-bit target explicitly
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    --default-host armv7-unknown-linux-gnueabihf

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