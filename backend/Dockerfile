FROM --platform=linux/arm/v7 python:3.10-slim-bookworm AS builder

WORKDIR /backend

# Use the PiWheels extra index to find pre-compiled 32-bit binaries
RUN pip install --upgrade pip && \
    pip config set global.extra-index-url https://www.piwheels.org/simple

COPY requirements.txt .

# This will now pull pre-built 'pydantic-core' and 'cryptography' wheels
RUN pip install --no-cache-dir --user -r requirements.txt



COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

COPY app ./app
COPY .env ./.env
COPY credentials.json ./app/core/credentials.json

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]