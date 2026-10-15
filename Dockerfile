# ==============================================================================
# Dockerfile — E-Commerce Big Data Analytics Using R
# Multi-runtime Container (R 4.x Analytics Engine + Python Web Orchestrator)
# Optimized for Render Web Service deployment
# ==============================================================================

FROM python:3.11-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PORT=10000 \
    RSCRIPT_PATH=/usr/bin/Rscript

# Install R runtime, compilers, and system development headers
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-base \
    r-base-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install required R analytical packages from CRAN
RUN Rscript -e "install.packages(c('data.table', 'lubridate', 'jsonlite', 'readxl', 'arules', 'forecast'), repos='https://cloud.r-project.org/', Ncpus=2)"

# Set application working directory
WORKDIR /app

# Copy project source tree
COPY . /app

# Ensure required runtime output directories exist
RUN mkdir -p output reports data datasets

# Pre-generate baseline analytics during image build for instant container startup
RUN Rscript run_analysis.R data/indian_ecommerce_data.csv indian_ecommerce_data.csv

# Render dynamically binds the external port via $PORT
EXPOSE 10000

# Start the Python analytical orchestrator
CMD ["python3", "tools/local_server.py"]
