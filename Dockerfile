# ============================================
# Boardgame App - Production Dockerfile
# ============================================

FROM python:3.14-slim

# Prevent Python from creating .pyc files
# and ensure logs are sent directly to stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# ------------------------------------------------
# Create non-root user
# UID/GID 10001 will be explicitly used by Kubernetes
# ------------------------------------------------
RUN groupadd --gid 10001 appgroup && \
    useradd --uid 10001 \
             --gid 10001 \
             --no-create-home \
             --shell /usr/sbin/nologin \
             appuser

# ------------------------------------------------
# Install Python dependencies
# ------------------------------------------------
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# ------------------------------------------------
# Copy application
# ------------------------------------------------
COPY --chown=10001:10001 . .

# ------------------------------------------------
# Make sure application belongs to non-root user
# ------------------------------------------------
RUN chown -R 10001:10001 /app

# ------------------------------------------------
# IMPORTANT:
# Use NUMERIC UID/GID.
# Do NOT use: USER appuser
# ------------------------------------------------
USER 10001:10001

# Application port
EXPOSE 8080

# ------------------------------------------------
# Container health check
# ------------------------------------------------
HEALTHCHECK --interval=30s \
            --timeout=5s \
            --start-period=15s \
            --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')" || exit 1

# ------------------------------------------------
# Start Flask application using Gunicorn
# ------------------------------------------------
CMD ["gunicorn", \
     "--bind", "0.0.0.0:8080", \
     "--workers", "2", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "app:app"]
