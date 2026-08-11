FROM python:3.14-slim

# Python runtime configuration
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Update OS packages and remove package lists
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Application directory
WORKDIR /app

# Create non-root user
RUN groupadd --gid 10001 appgroup \
    && useradd --uid 10001 \
       --gid 10001 \
       --no-create-home \
       --shell /usr/sbin/nologin \
       appuser

# Copy dependency file first for Docker layer caching
COPY requirements.txt .

# Upgrade Python packaging tools
RUN python -m pip install --upgrade \
    pip \
    setuptools \
    msgpack

# Install application dependencies
RUN python -m pip install --no-cache-dir -r requirements.txt

# Copy application
COPY --chown=10001:10001 . .

# Make sure application belongs to non-root user
RUN chown -R 10001:10001 /app

# Run as non-root
USER 10001:10001

# Application port
EXPOSE 8080

# Container health check
HEALTHCHECK --interval=30s \
            --timeout=5s \
            --start-period=15s \
            --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')" || exit 1

# Start application
CMD ["gunicorn", \
     "--bind", "0.0.0.0:8080", \
     "--workers", "2", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "app:app"]
