#!/usr/bin/env python3
"""
WordPress Article Crawler
Fetches articles from WordPress REST API and converts them to Markdown.
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import urljoin, urlparse

import html2text
import requests


class WordPressCrawler:
    """WordPress article crawler using REST API."""

    def __init__(self, wordpress_url, author_name, num_articles, output_dir):
        """
        Initialize the crawler.

        Args:
            wordpress_url: Base URL of WordPress site
            author_name: Author name or slug
            num_articles: Number of articles to fetch
            output_dir: Directory to save markdown files
        """
        # Validate and sanitize WordPress URL
        wordpress_url = wordpress_url.rstrip('/')
        parsed = urlparse(wordpress_url)
        if parsed.scheme not in ('http', 'https'):
            raise ValueError(f"Invalid URL scheme: {parsed.scheme}. Must be http or https.")
        
        self.wordpress_url = wordpress_url
        self.author_name = author_name
        
        # Validate number of articles
        try:
            self.num_articles = int(num_articles)
            if self.num_articles < 1:
                raise ValueError("Number of articles must be positive")
        except (ValueError, TypeError) as e:
            raise ValueError(f"Invalid number of articles: {num_articles}") from e
        
        self.output_dir = Path(output_dir)
        self.api_base = urljoin(self.wordpress_url + '/', 'wp-json/wp/v2/')
        
        # Configure HTML to Markdown converter
        self.html_converter = html2text.HTML2Text()
        self.html_converter.ignore_links = False
        self.html_converter.ignore_images = False
        self.html_converter.ignore_emphasis = False
        self.html_converter.body_width = 0  # Don't wrap lines
        self.html_converter.ignore_tables = False
        
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'WordPress-Article-Crawler/1.0'
        })

    def sanitize_filename(self, text):
        """Convert text to safe filename."""
        # Remove or replace invalid characters
        text = re.sub(r'[<>:"/\\|?*]', '', text)
        # Replace spaces and other whitespace with underscores
        text = re.sub(r'\s+', '_', text)
        # Limit length
        text = text[:200]
        text = text.strip('_')
        # Fallback for empty or invalid filenames
        if not text:
            text = 'untitled'
        return text

    def get_author_id(self):
        """Get author ID from author name or slug."""
        print(f"🔍 Looking up author: {self.author_name}")
        
        # Try to find author by slug first
        params = {'slug': self.author_name}
        url = urljoin(self.api_base, 'users')
        try:
            response = self.session.get(url, params=params, timeout=30)
            response.raise_for_status()
            users = response.json()
            
            if users:
                author_id = users[0]['id']
                author_name = users[0].get('name', self.author_name)
                print(f"✓ Found author: {author_name} (ID: {author_id})")
                return author_id
        except Exception as e:
            print(f"  Note: Could not find by slug: {e}")
        
        # Try searching by name
        params = {'search': self.author_name}
        url = urljoin(self.api_base, 'users')
        try:
            response = self.session.get(url, params=params, timeout=30)
            response.raise_for_status()
            users = response.json()
            
            if users:
                # Use first match
                author_id = users[0]['id']
                author_name = users[0].get('name', self.author_name)
                print(f"✓ Found author: {author_name} (ID: {author_id})")
                return author_id
        except Exception as e:
            print(f"  Note: Could not search by name: {e}")
        
        # If we couldn't find the author, return None
        print(f"⚠ Could not find author '{self.author_name}', will fetch articles without author filter")
        return None

    def fetch_articles(self, author_id=None):
        """
        Fetch articles from WordPress API.

        Args:
            author_id: Optional author ID to filter by

        Returns:
            List of article dictionaries
        """
        print(f"\n📥 Fetching up to {self.num_articles} articles...")
        
        articles = []
        page = 1
        per_page = min(100, self.num_articles)  # WordPress API max is 100
        
        while len(articles) < self.num_articles:
            # Build URL with parameters
            params = {
                'page': page,
                'per_page': per_page,
                'orderby': 'date',
                'order': 'desc',
                '_embed': True  # Include embedded data like author info
            }
            
            if author_id:
                params['author'] = author_id
            
            url = urljoin(self.api_base, 'posts')
            
            try:
                response = self.session.get(url, params=params, timeout=30)
                response.raise_for_status()
                
                posts = response.json()
                
                if not posts:
                    print(f"  No more articles found (page {page})")
                    break
                
                articles.extend(posts)
                print(f"  Page {page}: fetched {len(posts)} articles (total: {len(articles)})")
                
                # Check if we have enough articles
                if len(articles) >= self.num_articles:
                    articles = articles[:self.num_articles]
                    break
                
                # Check if there are more pages
                total_pages = response.headers.get('X-WP-TotalPages')
                if total_pages and page >= int(total_pages):
                    print(f"  Reached last page ({page})")
                    break
                
                page += 1
                
            except requests.exceptions.RequestException as e:
                print(f"❌ Error fetching articles: {e}")
                break
        
        print(f"✓ Fetched {len(articles)} articles total")
        return articles

    def convert_to_markdown(self, article):
        """
        Convert WordPress article to Markdown.

        Args:
            article: Article dictionary from API

        Returns:
            Tuple of (filename, markdown_content)
        """
        # Extract article data
        title = article.get('title', {}).get('rendered', 'Untitled')
        content = article.get('content', {}).get('rendered', '')
        excerpt = article.get('excerpt', {}).get('rendered', '')
        date_str = article.get('date', '')
        link = article.get('link', '')
        
        # Parse date
        try:
            date_obj = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
            date_formatted = date_obj.strftime('%Y-%m-%d')
        except (ValueError, AttributeError):
            date_formatted = 'unknown-date'
        
        # Get author name
        author = 'Unknown'
        if '_embedded' in article and 'author' in article['_embedded']:
            author_data = article['_embedded']['author']
            if isinstance(author_data, list) and author_data:
                author = author_data[0].get('name', 'Unknown')
        
        # Convert HTML to Markdown
        content_md = self.html_converter.handle(content)
        
        # Build markdown document
        markdown = f"# {title}\n\n"
        markdown += f"**Author:** {author}  \n"
        markdown += f"**Date:** {date_formatted}  \n"
        if link:
            markdown += f"**Original URL:** {link}  \n"
        markdown += "\n---\n\n"
        
        if excerpt:
            excerpt_md = self.html_converter.handle(excerpt)
            markdown += f"## Excerpt\n\n{excerpt_md}\n\n"
        
        markdown += content_md
        
        # Generate filename with article ID for uniqueness
        article_id = article.get('id', 'unknown')
        title_safe = self.sanitize_filename(title)
        filename = f"{date_formatted}_{article_id}_{title_safe}.md"
        
        return filename, markdown

    def save_articles(self, articles):
        """
        Save articles as Markdown files.

        Args:
            articles: List of article dictionaries
        """
        print(f"\n💾 Saving articles to {self.output_dir}")
        
        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        saved_count = 0
        for i, article in enumerate(articles, 1):
            try:
                filename, markdown = self.convert_to_markdown(article)
                filepath = self.output_dir / filename
                
                # Write file
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(markdown)
                
                print(f"  [{i}/{len(articles)}] {filename}")
                saved_count += 1
                
            except Exception as e:
                title = article.get('title', {}).get('rendered', 'Unknown')
                print(f"  ⚠ Error saving article '{title}': {e}")
        
        print(f"\n✓ Saved {saved_count} articles successfully")
        
        # Create summary file
        summary = {
            'wordpress_url': self.wordpress_url,
            'author_name': self.author_name,
            'requested_articles': self.num_articles,
            'fetched_articles': len(articles),
            'saved_articles': saved_count,
            'crawl_date': datetime.now().isoformat(),
            'output_directory': str(self.output_dir)
        }
        
        summary_file = self.output_dir / 'crawl_summary.json'
        with open(summary_file, 'w', encoding='utf-8') as f:
            json.dump(summary, f, indent=2)
        
        print(f"✓ Summary saved to crawl_summary.json")

    def run(self):
        """Run the complete crawling process."""
        try:
            # Get author ID
            author_id = self.get_author_id()
            
            # Fetch articles
            articles = self.fetch_articles(author_id)
            
            if not articles:
                print("❌ No articles found")
                return 1
            
            # Save articles
            self.save_articles(articles)
            
            return 0
            
        except Exception as e:
            print(f"\n❌ Fatal error: {e}")
            import traceback
            traceback.print_exc()
            return 1


def main():
    """Main entry point."""
    # Get configuration from environment variables
    wordpress_url = os.getenv('WORDPRESS_URL', '')
    author_name = os.getenv('AUTHOR_NAME', '')
    num_articles = os.getenv('NUM_ARTICLES', '10')
    output_dir = os.getenv('OUTPUT_DIR', '/output')
    
    # Validate required parameters
    if not wordpress_url:
        print("❌ Error: WORDPRESS_URL environment variable is required")
        return 1
    
    if not author_name:
        print("❌ Error: AUTHOR_NAME environment variable is required")
        return 1
    
    # Create crawler and run
    crawler = WordPressCrawler(wordpress_url, author_name, num_articles, output_dir)
    return crawler.run()


if __name__ == '__main__':
    sys.exit(main())
