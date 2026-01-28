#!/usr/bin/env bash
# ============================================================================
# Docker Entrypoint Script for WordPress Crawler
# ============================================================================
# This script is the default entrypoint for the container.
# It validates inputs and runs the Python crawler script.
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration from environment variables
# ============================================================================
WORDPRESS_URL="${WORDPRESS_URL:-}"
AUTHOR_NAME="${AUTHOR_NAME:-}"
NUM_ARTICLES="${NUM_ARTICLES:-10}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"

# ============================================================================
# Helper functions
# ============================================================================
show_banner() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║        WordPress Article Crawler - Docker                  ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

show_usage() {
    cat << 'EOF'
Usage: 
  docker run --rm \
    -v $(pwd)/output:/output \
    -e WORDPRESS_URL="https://example.com" \
    -e AUTHOR_NAME="john" \
    -e NUM_ARTICLES="10" \
    wordpress-crawler:latest

Environment Variables:
  WORDPRESS_URL    WordPress website URL (required)
  AUTHOR_NAME      Author name or slug (required)
  NUM_ARTICLES     Number of articles to fetch (default: 10)
  OUTPUT_DIR       Output directory path (default: /output)

Recommended: Use ./docker-build-run.sh from the host instead.
EOF
}

# ============================================================================
# Main logic
# ============================================================================
show_banner

# Handle help request
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_usage
    exit 0
fi

# Handle interactive shell mode
if [[ "${1:-}" == "/bin/bash" ]] || [[ "${1:-}" == "bash" ]] || [[ "${1:-}" == "shell" ]]; then
    echo "🔧 Starting interactive shell..."
    echo ""
    exec /bin/bash
fi

# ============================================================================
# Validate inputs
# ============================================================================
echo "📋 Configuration:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -z "$WORDPRESS_URL" ]]; then
    echo "❌ Error: WORDPRESS_URL environment variable is required"
    echo ""
    show_usage
    exit 1
fi

if [[ -z "$AUTHOR_NAME" ]]; then
    echo "❌ Error: AUTHOR_NAME environment variable is required"
    echo ""
    show_usage
    exit 1
fi

if ! [[ "$NUM_ARTICLES" =~ ^[0-9]+$ ]] || [[ "$NUM_ARTICLES" -lt 1 ]]; then
    echo "❌ Error: NUM_ARTICLES must be a positive integer"
    exit 1
fi

echo "  WordPress URL:  $WORDPRESS_URL"
echo "  Author:         $AUTHOR_NAME"
echo "  Articles:       $NUM_ARTICLES"
echo "  Output:         $OUTPUT_DIR"
echo ""

# ============================================================================
# Create output directory
# ============================================================================
mkdir -p "$OUTPUT_DIR"

# ============================================================================
# Run the crawler
# ============================================================================
echo "🚀 Starting crawler..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

python3 /usr/local/bin/fetch_articles.py

EXIT_CODE=$?

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✨ Crawling complete!"
    echo ""
    
    # Count markdown files
    MD_COUNT=$(find "$OUTPUT_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l)
    if [[ $MD_COUNT -gt 0 ]]; then
        echo "✅ Saved $MD_COUNT articles to $OUTPUT_DIR"
        echo ""
        
        # Show summary if available
        if [[ -f "$OUTPUT_DIR/crawl_summary.json" ]]; then
            echo "📊 Summary:"
            python3 -c "
import json
try:
    with open('$OUTPUT_DIR/crawl_summary.json') as f:
        data = json.load(f)
        print(f\"  WordPress:       {data.get('wordpress_url', 'N/A')}\")
        print(f\"  Author:          {data.get('author_name', 'N/A')}\")
        print(f\"  Requested:       {data.get('requested_articles', 'N/A')} articles\")
        print(f\"  Fetched:         {data.get('fetched_articles', 'N/A')} articles\")
        print(f\"  Saved:           {data.get('saved_articles', 'N/A')} articles\")
except Exception as e:
    print(f'  (Could not parse summary: {e})')
" 2>/dev/null || true
            echo ""
        fi
    else
        echo "⚠ No articles were saved"
    fi
    
    echo "✅ Done!"
else
    echo "❌ Crawling failed with exit code: $EXIT_CODE"
fi

exit $EXIT_CODE
