FROM --platform=linux/arm64 python:3.10-slim-bookworm AS builder

WORKDIR /backend

RUN apt-get update && apt-get install -y \
    libpq-dev \
    libffi-dev \
    libssl-dev \
    python3-dev \
    gcc \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install latest Rust via rustup properly, with PATH set immediately
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --profile minimal --default-toolchain stable
ENV PATH="/root/.cargo/bin:$PATH"

# Verify cargo is actually found before proceeding
RUN cargo --version && rustc --version

RUN pip install --upgrade pip setuptools && \
    pip config set global.extra-index-url https://www.piwheels.org/simple

RUN pip install --no-cache-dir --user grpcio==1.62.0 grpcio-status==1.62.0

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ---- Runtime stage ----
FROM --platform=linux/arm64 python:3.10-slim-bookworm

WORKDIR /backend

RUN apt-get update && apt-get install -y \
    libpq5 \
    libffi8 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

COPY app ./app
COPY .env ./.env
COPY credentials.json ./app/core/credentials.json

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]