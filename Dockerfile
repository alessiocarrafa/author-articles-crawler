# ------------------------------
# Dockerfile for WordPress Article Crawler
# ------------------------------
# Builds a lightweight container to fetch WordPress articles
# via REST API and convert them to Markdown format.
#
# Usage example:
#   docker build -t wordpress-crawler:latest .
#   docker run --rm \
#       -v $(pwd)/output:/output \
#       -e WORDPRESS_URL="https://example.com" \
#       -e AUTHOR_NAME="john" \
#       -e NUM_ARTICLES="10" \
#       wordpress-crawler:latest
# ------------------------------

FROM python:3.13.5-slim-bookworm AS base

# ------------------------------
# 1. OS-level dependencies
# ------------------------------
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------
# 2. Python environment
# ------------------------------
ENV VENV_PATH=/opt/venv
RUN python -m venv ${VENV_PATH}
ENV PATH="${VENV_PATH}/bin:${PATH}"

# Upgrade pip & install libraries
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    requests \
    html2text

# ------------------------------
# 3. Container setup
# ------------------------------
WORKDIR /workspace

# Copy scripts into the image
COPY scripts/fetch_articles.py /usr/local/bin/
COPY scripts/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
