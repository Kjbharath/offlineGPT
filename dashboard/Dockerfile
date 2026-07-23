FROM python:3.11-slim

# Install system utilities (nvidia-smi check, curl)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    procps \
    pciutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY app.py .
COPY templates ./templates

# Expose port
EXPOSE 8000

# Start server
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
