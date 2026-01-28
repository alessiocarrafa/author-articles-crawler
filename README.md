# WordPress Article Crawler

[](#wordpress-article-crawler)

Downloads articles from a WordPress website using the REST API and converts them to Markdown format.

## 🚀 Quick Start

[](#-quick-start)

```bash
./docker-build-run.sh https://wordpress.org john 10
```

Results in `./output/*.md` files

**Custom output directory:**

```bash
./docker-build-run.sh https://example.com "Jane Doe" 20 my_articles
```

* * *

## 📁 Project Structure

[](#-project-structure)

```
author-articles-crawler/
├── docker-build-run.sh     # Main entry point (builds & runs container)
├── Dockerfile              # Container configuration
├── output/                 # Downloaded articles (Markdown)
├── scripts/
│   ├── fetch_articles.py       # WordPress API crawler (runs in container)
│   └── entrypoint.sh           # Container entrypoint (runs in container)
└── README.md
```

* * *

## 📋 Usage

[](#-usage)

### Basic Usage

```bash
./docker-build-run.sh <wordpress_url> <author_name> [num_articles] [output_dir]
```

**Arguments:**

*   `wordpress_url` - WordPress website URL (required, e.g., `https://example.com`)
*   `author_name` - Author name or slug to filter articles (required)
*   `num_articles` - Number of articles to fetch, latest to backward (optional, default: 10)
*   `output_dir` - Output directory for markdown files (optional, default: `output`)

### Examples

**Download 20 articles from WordPress.org by author "john":**

```bash
./docker-build-run.sh https://wordpress.org john 20
```

**Download 5 articles with custom output directory:**

```bash
./docker-build-run.sh https://example.com "Jane Doe" 5 my_articles
```

**Download default 10 articles:**

```bash
./docker-build-run.sh https://techblog.com alice
```

* * *

## 📤 Output

[](#-output)

### Markdown Files

Each article is saved as a Markdown file with the following format:

```markdown
# Article Title

**Author:** John Doe  
**Date:** 2024-01-15  
**Original URL:** https://example.com/article-slug  

---

## Excerpt

Brief excerpt or summary...

Article content converted to Markdown...
```

**Filename format:** `YYYY-MM-DD_Article_Title.md`

### Summary File

A `crawl_summary.json` file is created with metadata:

```json
{
  "wordpress_url": "https://example.com",
  "author_name": "john",
  "requested_articles": 10,
  "fetched_articles": 10,
  "saved_articles": 10,
  "crawl_date": "2024-01-15T10:30:00",
  "output_directory": "/path/to/output"
}
```

* * *

## 🔧 Technical Details

[](#-technical-details)

### WordPress REST API

The crawler uses the WordPress REST API v2 endpoints:

*   `/wp-json/wp/v2/users` - Find author by name or slug
*   `/wp-json/wp/v2/posts` - Fetch articles with filters

**Features:**

*   Automatic pagination (handles large article counts)
*   Filters by author ID
*   Sorts by date (latest first)
*   Fetches embedded author information
*   Respects API rate limits

### Conversion

*   HTML content is converted to clean Markdown using `html2text`
*   Preserves links, images, formatting, and tables
*   Generates safe filenames from article titles
*   Includes metadata header in each file

* * *

## 🐳 Docker

[](#-docker)

Everything runs in a container - no local dependencies needed.

**Requirements:** Docker installed

**Manual Docker Usage:**

```bash
# Build image
docker build -t wordpress-crawler:latest .

# Run crawler
docker run --rm \
  -v $(pwd)/output:/output \
  -e WORDPRESS_URL="https://example.com" \
  -e AUTHOR_NAME="john" \
  -e NUM_ARTICLES="10" \
  wordpress-crawler:latest
```

**Interactive shell (for debugging):**

```bash
docker run --rm -it \
  -v $(pwd)/output:/output \
  wordpress-crawler:latest bash
```

* * *

## ⚠️ Troubleshooting

[](#️-troubleshooting)

**Docker not found:**

```bash
curl -fsSL https://get.docker.com | sh
```

**Permission denied:**

```bash
chmod +x docker-build-run.sh
```

**Author not found:**

*   Try using the author's slug instead of full name
*   Check the author exists on the WordPress site
*   The crawler will proceed without author filter if not found

**No articles returned:**

*   Verify the WordPress site has REST API enabled
*   Check the author has published articles
*   Try without author filter to test API connectivity

**API errors:**

*   Some WordPress sites may have API restrictions
*   Check if the site requires authentication
*   Verify the URL is correct and accessible

* * *

## 📝 Architecture

[](#-architecture)

This project follows the same architecture pattern as [author-style-synth](https://github.com/alessiocarrafa/author-style-synth):

1.  **Main entry script** (`docker-build-run.sh`) - Validates inputs, builds Docker image, runs container
2.  **Docker container** - Isolated environment with all dependencies
3.  **Entrypoint script** (`entrypoint.sh`) - Container initialization and orchestration
4.  **Core logic** (`fetch_articles.py`) - WordPress API interaction and Markdown conversion
5.  **Volume mounting** - Output directory shared between container and host

**Benefits:**

*   No local Python/dependencies required
*   Consistent execution environment
*   Easy to run on any system with Docker
*   Clean separation of concerns

* * *

**Language:** Python | **Updated:** 2026-01-28
