# ArxivSDK Skill Documentation

## Overview
The ArxivSDK is based on the `arxiv.py` Python library, a wrapper for the arXiv API. It allows searching, fetching metadata, and downloading content from arXiv.org, a repository of over 1 million scholarly papers in physics, math, CS, etc.

### Installation
```bash
pip install arxiv
# Or uv add arxiv
```

### Basic Usage
```python
import arxiv

# Default client
client = arxiv.Client()
search = arxiv.Search(query="quantum", max_results=10, sort_by=arxiv.SortCriterion.SubmittedDate)
results = client.results(search)

for result in results:
    print(result.title)
```

## Core Classes and Methods

### Client Class
Manages API interactions, pagination, and rate limiting.

#### Constructor: `Client(page_size=100, delay_seconds=3.0, num_retries=3)`
- **Parameters**:
  - `page_size` (int): Number of results per API request (max 2000, default 100).
  - `delay_seconds` (float): Delay between requests to avoid rate limits (default 3.0).
  - `num_retries` (int): Number of retries on failure (default 3).
- **Description**: Reusable client for efficient fetching. Successive calls reuse connections and respect rate limits.

#### Method: `results(search: Search) -> Generator[Result, None, None]`
- **Parameters**: `search` (Search): The search query object.
- **Returns**: Generator yielding `Result` objects.
- **Description**: Executes the search and yields results lazily. Handles pagination internally.
- **Example**:
  ```python
  client = arxiv.Client(page_size=50)
  search = arxiv.Search(query="machine learning", max_results=100)
  for result in client.results(search):
      print(result.title)
  ```

### Search Class
Defines search parameters for querying arXiv.

#### Constructor: `Search(query="", max_results=10, sort_by=SortCriterion.Relevance, sort_order=SortOrder.Descending, id_list=None)`
- **Parameters**:
  - `query` (str): Search query string (supports advanced syntax, e.g., "au:author AND ti:title").
  - `max_results` (int): Max results to return (default 10, up to 30000).
  - `sort_by` (SortCriterion): Sort field (Relevance, LastUpdatedDate, SubmittedDate).
  - `sort_order` (SortOrder): Ascending or Descending.
  - `id_list` (list[str] or None): List of specific paper IDs to fetch.
- **Description**: Specifies the search criteria. Use `id_list` for direct ID lookups.
- **Examples**:
  ```python
  # Keyword search
  search = arxiv.Search(query="quantum computing", max_results=5)

  # ID-based search
  search = arxiv.Search(id_list=["1605.08386v1"])

  # Advanced query
  search = arxiv.Search(query="au:del_maestro AND ti:checkerboard")
  ```

### Result Class
Represents a single paper's metadata.

#### Attributes
- `entry_id` (str): URL like "https://arxiv.org/abs/{id}".
- `updated` (datetime): Last update time.
- `published` (datetime): Publication time.
- `title` (str): Paper title.
- `authors` (list[Result.Author]): List of authors.
- `summary` (str): Abstract.
- `comment` (str or None): Author's comment.
- `journal_ref` (str or None): Journal reference.
- `doi` (str or None): DOI URL.
- `primary_category` (str): Main arXiv category (e.g., "cs.AI").
- `categories` (list[str]): All categories.
- `links` (list[Result.Link]): Associated URLs (PDF, etc.).
- `pdf_url` (str or None): Direct PDF URL.

#### Methods
##### `get_short_id() -> str`
- **Returns**: Short ID (e.g., "2107.05580v1").
- **Description**: Extracts ID from entry_id.
- **Example**: `result.get_short_id()  # "2107.05580v1"`

##### `download_pdf(dirpath="./", filename="", download_domain="export.arxiv.org") -> str`
- **Parameters**:
  - `dirpath` (str): Directory to save (default "./").
  - `filename` (str): Custom filename (auto-generated if empty).
  - `download_domain` (str): Domain for download (for testing).
- **Returns**: Path to saved file.
- **Raises**: ValueError if no PDF URL.
- **Description**: Downloads PDF. Deprecated; use `pdf_url` directly in future.
- **Example**:
  ```python
  path = result.download_pdf(dirpath="./papers")
  ```

##### `download_source(dirpath="./", filename="", download_domain="export.arxiv.org") -> str`
- **Parameters**: Same as download_pdf.
- **Returns**: Path to saved tar.gz file.
- **Description**: Downloads source tarfile. Deprecated; derive from `source_url`.
- **Example**: Similar to download_pdf.

##### `source_url() -> str or None`
- **Returns**: URL for source tarfile or None.
- **Description**: Derives source URL from PDF URL.
- **Example**: `url = result.source_url()`

### Author Class (Subclass of Result)
Represents an author.

#### Attributes
- `name` (str): Author's name.

#### Methods
- `__str__()`: Returns name.
- `__repr__()`: Formatted string.

### Link Class (Subclass of Result)
Represents a link.

#### Attributes
- `href` (str): URL.
- `title` (str or None): Link title.
- `rel` (str): Relationship (e.g., "alternate").
- `content_type` (str or None): MIME type.

#### Methods
- `__str__()`: Returns href.
- `__repr__()`: Formatted string.

### Enums
#### SortCriterion
- `Relevance`: Sort by relevance.
- `LastUpdatedDate`: Sort by last update.
- `SubmittedDate`: Sort by submission.

#### SortOrder
- `Ascending`
- `Descending`

### Exceptions
#### MissingFieldError
- Raised if required fields (e.g., "id") are missing from API response.

## Integration with Arxiv Agent
- **LangGraph Nodes**: Use Client in search node, Result in analysis/summarize nodes.
- **Ollama**: Pass Result.summary to LLM for summarization.
- **Storage**: Store Result metadata in JSON/DB; save downloads locally.
- **Best Practices**: Respect rate limits; handle retries; log with `logging.basicConfig(level=logging.DEBUG)`.

## Full Workflow Example
```python
import arxiv

client = arxiv.Client()
search = arxiv.Search(query="AI ethics", max_results=3)
results = list(client.results(search))

for result in results:
    print(f"Title: {result.title}")
    print(f"Authors: {[a.name for a in result.authors]}")
    print(f"Summary: {result.summary[:200]}...")
    if result.pdf_url:
        result.download_pdf("./downloads")
```

This covers all endpoints and functions for comprehensive use in the ResearchAgent.