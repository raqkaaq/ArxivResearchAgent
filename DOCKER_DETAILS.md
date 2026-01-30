# Docker Infrastructure Details

This document describes the Docker-based infrastructure for the ArxivResearchAgent project, including database services, ML serving, and vector search capabilities.

## Overview

The project uses Docker Compose to orchestrate 4 services:

| Service | Purpose | Image | Host Ports |
|---------|---------|-------|------------|
| **Neo4j** | Graph database for research relationships | `neo4j:latest` | 7475 (HTTP), 7688 (Bolt) |
| **PostgreSQL + pgvector** | Relational DB + vector similarity search | `pgvector/pgvector:pg16-bookworm` | 5433 |
| **Ollama Server** | Local LLM inference runtime | `ollama/ollama:latest` | 11435 |
| **Ollama WebUI** | Web interface for Ollama | `ghcr.io/ollama-webui/ollama-webui:main` | 3011 |

## Quick Start

```bash
# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f

# Stop all services
docker compose down
```

## Service Details

### 1. Neo4j Graph Database

**Purpose:** Store and query research paper relationships (citations, authors, topics, dependencies).

**Ports:**
- `7475` - HTTP API (Neo4j Browser)
- `7688` - Bolt protocol (client connections)

**Authentication:**
- Default username: `neo4j`
- Password: Set via `NEO4J_AUTH` in `.env`

**APOC Plugin:** APOC Core is pre-installed and enabled, providing 500+ utility procedures for:
- Data import/export (JSON, CSV, XML)
- Graph algorithms (PageRank, community detection)
- Text processing and utilities

**Example Cypher query:**
```cypher
// Find papers by author
MATCH (a:Author {name: "John Doe"})-[:WROTE]->(p:Paper)
RETURN p.title, p.year

// Get citation network
MATCH (p:Paper)-[:CITES]->(c:Paper)
RETURN p.title, count(c) as citation_count ORDER BY citation_count DESC
```

### 2. PostgreSQL with pgvector

**Purpose:** Structured data storage + vector embeddings for semantic search.

**Port:** `5433` (host) → `5432` (container)

**Credentials:**
- Database: `arxiv` (or set via `POSTGRES_DB`)
- Username: `postgres` (or set via `POSTGRES_USER`)
- Password: `postgres` (or set via `POSTGRES_PASSWORD`)

**pgvector Extension:** v0.8.1 for vector similarity search.

**Enable extension:**
```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

**Create vector column:**
```sql
CREATE TABLE embeddings (
    id SERIAL PRIMARY KEY,
    paper_id VARCHAR(50),
    embedding vector(1536),  -- OpenAI text-embedding-3-small dimensions
    content TEXT
);

-- Create HNSW index for fast similarity search
CREATE INDEX ON embeddings USING hnsw (embedding vector_cosine_ops);
```

**Similarity search query:**
```sql
-- Find semantically similar papers
SELECT id, paper_id, 1 - (embedding <=> query_vector) AS similarity
FROM embeddings
ORDER BY embedding <=> query_vector
LIMIT 10;
```

### 3. Ollama Server

**Purpose:** Local LLM inference for embeddings and text generation.

**Port:** `11435` (host) → `11434` (container)

**Usage:**
```bash
# Pull a model
docker exec -it ollama-server-arxiv ollama pull nomic-embed-text

# List available models
docker exec -it ollama-server-arxiv ollama list

# Test generation
docker exec -it ollama-server-arxiv ollama run llama3.2 "What is machine learning?"
```

**Environment:**
- Models stored in: `${OLLAMA_PATH}/ollama_data` (mounted from host)
- GPU support: Enabled via NVIDIA runtime
- Restart policy: `unless-stopped`

### 4. Ollama WebUI

**Purpose:** Browser-based interface for interacting with Ollama.

**Port:** `3011` (host) → `8080` (container)

**Access:** Open http://localhost:3011 in your browser

**Configuration:**
- Connects to Ollama Server via: `http://ollama-server:11434`
- Chat history stored in: `${OLLAMA_PATH}/webui`

## Directory Structure

```
ArxivResearchAgent/
├── docker-compose.yml          # Main orchestration file
├── .env                        # Environment variables
├── data/
│   ├── neo4j/                 # Neo4j data (auto-created)
│   ├── postgres/              # PostgreSQL data (auto-created)
│   └── ollama/                # Ollama models (set via OLLAMA_PATH)
├── neo4j/
│   ├── plugins/               # Neo4j plugins (APOC)
│   │   └── .gitkeep
│   └── conf/
│       └── apoc.conf          # APOC configuration
└── postgres/
    └── init/
        └── 01-create-extensions.sql  # Extension initialization
```

## Environment Variables

Create a `.env` file with the following variables:

```bash
# Database credentials
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=arxiv

# Neo4j credentials (format: username/password)
NEO4J_AUTH=neo4j/your_password

# Ollama configuration
OLLAMA_PATH=/path/to/ollama/data

# Optional: Neo4j memory settings
NEO4J_server_memory_heap__max__size=2G
NEO4J_server_memory_pagecache__size=1G
```

## Data Persistence

All services use Docker volumes for data persistence:

| Service | Volume Type | Location |
|---------|------------|----------|
| Neo4j | Bind mount + named volume | `./data/neo4j/` + `neo4j-data` |
| PostgreSQL | Bind mount + named volume | `./data/postgres/` + `postgres-data` |
| Ollama | Bind mount | `${OLLAMA_PATH}/ollama_data` |
| Ollama WebUI | Bind mount | `${OLLAMA_PATH}/webui` |

**To reset all data:**
```bash
docker compose down
rm -rf data/neo4j data/postgres
docker compose up -d
```

## Port Reference

| Service | Container Port | Host Port | Protocol |
|---------|---------------|-----------|----------|
| Neo4j HTTP | 7474 | 7475 | HTTP |
| Neo4j Bolt | 7687 | 7688 | TCP |
| PostgreSQL | 5432 | 5433 | TCP |
| Ollama Server | 11434 | 11435 | HTTP |
| Ollama WebUI | 8080 | 3011 | HTTP |

## Health Checks

All services include health checks:

```bash
# Check health status
docker compose ps

# View health check details
docker inspect arxiv-neo4j | jq '.[0].State.Health'
docker inspect arxiv-postgres | jq '.[0].State.Health'
```

## Troubleshooting

### Neo4j

**Check if APOC is loaded:**
```bash
docker exec arxiv-neo4j ls /plugins/apoc.jar
docker exec arxiv-neo4j cypher-shell -u neo4j -p <password> "CALL apoc.help('apoc') YIELD name RETURN count(*)"
```

**View logs:**
```bash
docker logs arxiv-neo4j
docker logs arxiv-neo4j --tail 100 | grep -i error
```

### PostgreSQL

**Verify pgvector:**
```bash
docker exec arxiv-postgres psql -U postgres -d arxiv -c "SELECT * FROM pg_extension WHERE extname='vector';"
```

**Test connection:**
```bash
docker exec -it arxiv-postgres psql -U postgres -d arxiv
```

### Ollama

**Check if models are downloading:**
```bash
docker logs ollama-server-arxiv --tail 50
```

**Pull a model:**
```bash
docker exec ollama-server-arxiv ollama pull nomic-embed-text
```

### General

**Restart all services:**
```bash
docker compose restart

# Or restart individual service
docker compose restart neo4j
docker compose restart postgres
docker compose restart ollama-server
docker compose restart ollama-webui
```

**Clean up and rebuild:**
```bash
docker compose down -v
docker compose up -d --build
```

## Performance Tuning

### Neo4j Memory

Add to `.env`:
```bash
NEO4J_server_memory_heap__max__size=4G
NEO4J_server_memory_pagecache__size=2G
```

### PostgreSQL

Adjust `maintenance_work_mem` for faster vector index builds:
```sql
SET maintenance_work_mem = '2GB';
CREATE INDEX ON embeddings USING hnsw (embedding vector_cosine_ops);
```

### Ollama

For GPU acceleration, ensure NVIDIA runtime is configured in Docker:
```bash
docker run --gpus all ollama/ollama:latest
```

## Security Notes

- Change default passwords in `.env` before deployment
- Neo4j browser access is unauthenticated by default in development
- Consider using Docker secrets for production deployments
- Neo4j APOC procedures like `apoc.export.file.enabled` should be disabled in production

## Networking

All services communicate via a shared bridge network (`arxivresearchagent_neo4j-network`):

| Service | Internal Hostname |
|---------|------------------|
| Neo4j | `neo4j:7474` |
| PostgreSQL | `postgres:5432` |
| Ollama Server | `ollama-server:11434` |
| Ollama WebUI | `ollama-webui:8080` |

Example connection strings:
- Neo4j: `bolt://neo4j:7687`
- PostgreSQL: `postgresql://postgres:postgres@postgres:5432/arxiv`
- Ollama: `http://ollama-server:11434`
