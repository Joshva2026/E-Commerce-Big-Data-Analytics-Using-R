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

# Install system tools, development libraries, and official CRAN Debian repository
RUN apt-get update && apt-get install -y --no-install-recommends \
    dirmngr \
    gnupg \
    ca-certificates \
    curl \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    build-essential \
    && mkdir -p /etc/apt/trusted.gpg.d \
    && (curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x95C0FAF38DB3CCAD0C080A7BDC78B2DDEABC47B7" | gpg --dearmor -o /etc/apt/trusted.gpg.d/cran_debian_key.gpg 2>/dev/null || true) \
    && echo "deb [trusted=yes] https://cloud.r-project.org/bin/linux/debian bookworm-cran40/" > /etc/apt/sources.list.d/cran.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    r-base \
    r-base-dev \
    && rm -rf /var/lib/apt/lists/*

# Install required R analytical packages from CRAN with fallback to CRAN archive
RUN Rscript -e "\
    options(repos = c(CRAN = 'https://cloud.r-project.org/')); \
    pkgs <- c('data.table', 'lubridate', 'jsonlite', 'readxl', 'forecast'); \
    install.packages(pkgs, Ncpus = 2); \
    # Install arules from CRAN \
    tryCatch(install.packages('arules', Ncpus = 2), error = function(e) NULL); \
    # Fallback to CRAN archive if arules requires an alternate R release \
    if (!requireNamespace('arules', quietly = TRUE)) { \
        message('Installing compatible arules release from CRAN Archive...'); \
        install.packages('https://cran.r-project.org/src/contrib/Archive/arules/arules_1.7-7.tar.gz', repos = NULL, type = 'source'); \
    }; \
    for (p in c(pkgs, 'arules')) { \
        if (!requireNamespace(p, quietly = TRUE)) stop(paste('Critical package missing:', p)); \
    }"

# Verify arules installation as required
RUN Rscript -e "library(arules); packageVersion('arules')"

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
