FROM python:3.11

WORKDIR /backend

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# Copy the app directory
COPY app ./app

# Copy environment variables and credentials into the image
# This is safe because they are created in the build context by the workflow
COPY .env ./.env
COPY credentials.json ./app/core/credentials.json

EXPOSE 8000

# Now app.main:app will work because we are in /backend and there is an app/ directory
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
