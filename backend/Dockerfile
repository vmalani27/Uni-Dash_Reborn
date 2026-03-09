FROM --platform=linux/arm/v7 python:3.10-slim-bookworm AS builder

WORKDIR /backend

# Only install basic C build tools for other python libs (like psycopg2)
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    libssl-dev \
    libffi-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Install dependencies - pip will now find the pre-compiled ARMv7 wheels
RUN pip install --upgrade pip && \
    pip install --no-cache-dir --user -r requirements.txt

FROM --platform=linux/arm/v7 python:3.10-slim-bookworm
WORKDIR /backend

# Runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl3 \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

COPY app ./app
COPY .env ./.env
COPY credentials.json ./app/core/credentials.json

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]