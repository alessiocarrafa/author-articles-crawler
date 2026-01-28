#!/usr/bin/env bash
# ============================================================================
# docker-build-run.sh - Build Docker image and run WordPress crawler
# ============================================================================
set -euo pipefail

# ============================================================================
# Configuration & Defaults
# ============================================================================
WORDPRESS_URL="${1:-}"
AUTHOR_NAME="${2:-}"
NUM_ARTICLES="${3:-10}"
OUTPUT_DIR="${4:-output}"
IMAGE_NAME="wordpress-crawler:latest"

# ============================================================================
# Usage
# ============================================================================
show_usage() {
    cat << 'EOF'
Usage: ./docker-build-run.sh <wordpress_url> <author_name> [num_articles] [output_dir]

Arguments:
  wordpress_url    WordPress website URL (e.g., https://example.com)
  author_name      Author name or slug to filter articles
  num_articles     Number of articles to fetch (default: 10)
  output_dir       Output directory for markdown files (default: output)

Examples:
  ./docker-build-run.sh https://wordpress.org john 20
  ./docker-build-run.sh https://example.com "Jane Doe" 5 my_articles

EOF
}

# ============================================================================
# Validation
# ============================================================================
if [[ -z "$WORDPRESS_URL" ]] || [[ -z "$AUTHOR_NAME" ]]; then
    echo "❌ Error: WordPress URL and author name are required"
    echo ""
    show_usage
    exit 1
fi

# Validate WordPress URL format
if [[ ! "$WORDPRESS_URL" =~ ^https?:// ]]; then
    echo "❌ Error: WordPress URL must start with http:// or https://"
    exit 1
fi

# Validate number of articles
if ! [[ "$NUM_ARTICLES" =~ ^[0-9]+$ ]] || [[ "$NUM_ARTICLES" -lt 1 ]]; then
    echo "❌ Error: Number of articles must be a positive integer"
    exit 1
fi

# Create and resolve output directory
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# ============================================================================
# Display Configuration
# ============================================================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        WordPress Article Crawler                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 Configuration:"
echo "  WordPress URL:  $WORDPRESS_URL"
echo "  Author:         $AUTHOR_NAME"
echo "  Articles:       $NUM_ARTICLES (latest to backward)"
echo "  Output:         $OUTPUT_DIR"
echo ""

# ============================================================================
# Build Docker Image
# ============================================================================
echo "🔨 Building Docker image: $IMAGE_NAME"
docker build -t "$IMAGE_NAME" .

# ============================================================================
# Run Container
# ============================================================================
echo ""
echo "🚀 Running crawler in container..."
docker run --rm \
  -v "$OUTPUT_DIR:/output" \
  -e WORDPRESS_URL="$WORDPRESS_URL" \
  -e AUTHOR_NAME="$AUTHOR_NAME" \
  -e NUM_ARTICLES="$NUM_ARTICLES" \
  "$IMAGE_NAME"

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "✅ Done! Articles saved to: $OUTPUT_DIR"
echo ""
