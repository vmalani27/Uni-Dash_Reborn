FROM --platform=linux/arm64 python:3.10-slim-bookworm AS builder

WORKDIR /backend

RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip && \
    pip config set global.extra-index-url https://www.piwheels.org/simple

COPY requirements.txt .

RUN pip install --no-cache-dir --user -r requirements.txt

# ---- Runtime stage ----
FROM --platform=linux/arm64 python:3.10-slim-bookworm

WORKDIR /backend

# Only need the runtime postgres lib, not the dev headers
RUN apt-get update && apt-get install -y \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

COPY app ./app
COPY .env ./.env
COPY credentials.json ./app/core/credentials.json

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]