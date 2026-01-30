# Data Product Requirements Document: Semantic Scholar SDK Integration

## Overview
This PRD outlines the integration of an external Semantic Scholar SDK into the Arxiv Research Agent, focusing on efficient access to paper and author metadata (e.g., citations, h-index, paper counts) to support the quality classification engine and relevance engine. The SDK (developed elsewhere) will provide a robust, rate-limited interface to Semantic Scholar's API, enabling data collection for fine-tuning models on authors and categories. It builds on the need for richer metadata beyond Arxiv, with data flowing to PostgreSQL for embeddings and Neo4j for persistent graph relationships.

The SDK aims to be a lightweight, Python-based wrapper that handles API complexities, caching, and error recovery, ensuring reliable data flow for offline model training and real-time agent queries.

## Goals
- **Primary**: Provide a reliable SDK for fetching Semantic Scholar data (papers, authors, citations) to store in PostgreSQL and build Neo4j relationship graphs for training/enriching the quality classification model.
- **Secondary**: Enable real-time agent access to author/paper metrics for relevance scoring.
- **Non-Goals**: Full replacement of Arxiv; handling non-academic data.

## Key Approaches for a Good Semantic Scholar SDK
To create an effective SDK, focus on these approaches, drawing from API best practices and integration patterns:

### 1. API Wrapper Design
- **Core Functionality**: Wrap Semantic Scholar's REST API (e.g., paper search, author lookup) with Python classes/methods. Use `requests` for HTTP calls; parse JSON responses into structured objects (e.g., `Paper` with citations, authors).
- **Endpoints Coverage**: Prioritize paper details (citations, influential citations, authors), author profiles (papers count, citations, h-index). Support queries by DOI, title, author name, or ID.
- **PostgreSQL Storage**: Store embeddings in PostgreSQL with pgvector for semantic similarity search.
- **Neo4j Integration**: Build persistent citation graphs from Semantic Scholar data.

### 2. Rate Limiting and Error Handling
- **Rate Limiting**: Semantic Scholar has a 1000 requests/day free limit. Implement backoff (e.g., via `tenacity` library) and batching to avoid hitting limits. Track usage with a counter.
- **Error Handling**: Retry on 429 (rate limit) or 5xx errors; log failures. Handle 404s (not found) gracefully; cache 200 responses to reduce calls.
- **Robustness**: Add timeouts; validate API responses; fallback to cached data if API fails.

### 3. Caching and Efficiency
- **Caching Layer**: Use `diskcache` for API responses (TTL-based, e.g., 24h). Avoid re-fetching for same queries.
- **Batch Queries**: For multiple papers/authors, use bulk endpoints or parallel requests to optimize.
- **Data Compression**: Store parsed data efficiently (e.g., JSON).

### 4. Data Integration
- **PostgreSQL Storage**: Store embeddings alongside Arxiv data for unified semantic search.
- **Neo4j Graph Building**: Create persistent citation graphs from Semantic Scholar data.
- **Cross-References**: Maintain paper IDs for linking between PostgreSQL embeddings and Neo4j graphs.

### 5. Integration and Extensibility
- **Orchestral AI Compatibility**: Design as a tool/provider for Orchestral AI (e.g., custom retriever for citations).
- **Neo4j Integration**: Provide methods for graph construction from Semantic Scholar data.
- **Configurable**: Support API keys, custom endpoints; allow switching to Arxiv fallback.
- **Testing**: Unit tests for API calls; mock responses for reliability.

## Integration with Arxiv Agent
- **Quality Classification**: Fetch author features (citations, papers) for model training; categories for labeling.
- **Relevance Engine**: Real-time API calls for scoring; cached in diskcache; graph data available in Neo4j for enhanced relevance.
- **Hybrid Use**: SDK supplements Arxiv data stored in PostgreSQL; Neo4j builds enhanced citation networks.

## Requirements and Tradeoffs
- **Functional**: Fetch citations/h-index reliably; handle 1000+ queries/day; store in PostgreSQL; build Neo4j relationships.
- **Non-Functional**: <1s response (with caching); PostgreSQL storage efficiency; Neo4j graph operations.
- **Dependencies**: requests, tenacity, diskcache, psycopg2-binary, neo4j, pgvector.
- **Tradeoffs**: Free tier limits scale; diskcache increases storage but improves speed; Neo4j adds relationship analysis power; persistent graph simplifies architecture and preserves data across restarts.

## Implementation Roadmap
1. Setup: Base wrapper and API key handling; PostgreSQL tables for embeddings; Neo4j graph schema.
2. Core: Rate limiting, parsing, caching; Neo4j relationship construction.
3. Integration: Connect to quality classification; build Neo4j relationship graphs from citation data.
4. Testing: Validate with sample data; test graph consistency; performance testing under load.
5. Performance Optimization: Implement caching strategies; graph query optimization.

## HuggingFace Dataset Seeding

### Overview
The system uses HuggingFace datasets as the initial data source for seeding the research database with approximately 2M papers. This provides a comprehensive foundation before integrating live Arxiv API updates.

### Implementation
```python
# HuggingFace loader for initial seeding
class HuggingFaceLoader:
    """Efficient dataset loading for initial paper seeding"""
    
    def __init__(self, dataset_name: str = "papers-with-abstracts"):
        self.dataset_name = dataset_name
        self.batch_size = 1000
        
    async def load_and_process(self, processor: PaperProcessor):
        """Load papers in batches and process for storage"""
        from datasets import load_dataset
        dataset = load_dataset(self.dataset_name, split="train")
        
        for batch in dataset.iter(batch_size=self.batch_size):
            processed_papers = []
            for paper in batch:
                processed_papers.append(processor.clean(paper))
            
            await batch_importer.bulk_insert(processed_papers)
```

### Performance Targets for Seeding
- **Bulk Import**: <5 minutes for 2M papers
- **Paper Insert**: <10ms per batch
- **Import Success Rate**: >99%

### Integration Points
- Outputs processed papers to `data_ingestion/paper_processor.py`
- Feeds into `database/postgres_setup.py` for partitioned storage
- Generates initial embeddings via `embeddings/embedding_manager.py`

## Semantic Scholar SDK Integration

This SDK will enable powerful data collection for the classification engine and Neo4j relationship graphs. Reference PRD.md for overall system integration.