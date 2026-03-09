FROM --platform=linux/arm/v7 python:3.11-slim-bookworm AS builder

WORKDIR /backend

RUN pip install --upgrade pip && \
    pip config set global.extra-index-url https://www.piwheels.org/simple

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ---- Runtime stage ----
FROM --platform=linux/arm/v7 python:3.11-slim-bookworm

WORKDIR /backend

COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

COPY app ./app
# No COPY for .env or credentials.json - mounted at runtime via docker run -v

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]