FROM python:3.10

WORKDIR /backend

# Install build dependencies
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
    && rm -rf /var/lib/apt/lists/*

# Copy Rust toolchain from official image (much more reliable than curl | sh)
COPY --from=rust:latest /usr/local/cargo /usr/local/cargo
COPY --from=rust:latest /usr/local/rustup /usr/local/rustup

# Set Rust environment variables
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

COPY requirements.txt .

RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# Copy the app directory
COPY app ./app

# Copy environment variables and credentials into the image
COPY .env ./.env
COPY credentials.json ./app/core/credentials.json

EXPOSE 8000

# Now app.main:app will work
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
