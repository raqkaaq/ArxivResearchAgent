# Docker Skill

This skill handles Docker-based infrastructure for the ArxivResearchAgent project, including service orchestration with docker-compose and GPU-enabled container configuration.

## Features
- Docker Compose service management (Neo4j, PostgreSQL/pgvector, Ollama, Ollama WebUI).
- NVIDIA GPU container configuration for Ollama.
- Service health monitoring and troubleshooting.
- Data persistence with Docker volumes.

## Usage
Load this skill when working with Docker services for the research agent. Use for starting/stopping services, troubleshooting, and GPU configuration.

## Prerequisites

### NVIDIA GPU Setup
**IMPORTANT**: Before running Ollama with GPU support, you MUST set Docker to use the NVIDIA runtime. This is achieved using the following command. Run:

```bash
docker_default
```

This command configures Docker to use the NVIDIA container runtime, which is required for Ollama GPU acceleration. Without this, Ollama will run in CPU-only mode with significantly degraded performance.

To verify GPU access:
```bash
docker exec -it ollama-server-arxiv nvidia-smi
```

### Verify Docker NVIDIA Runtime
```bash
docker info | grep -i runtime
```

You should see `nvidia` in the list of runtimes.

## Service Management

### Start All Services
```bash
docker compose up -d
```

### Check Service Status
```bash
docker compose ps
```

### View Logs
```bash
docker compose logs -f
docker compose logs -f ollama-server
```

### Stop All Services
```bash
docker compose down
```

### Restart Services
```bash
docker compose restart
docker compose restart ollama-server
```

## Services Overview

| Service | Purpose | Ports |
|---------|---------|-------|
| **Neo4j** | Graph database for research relationships | 7475 (HTTP), 7688 (Bolt) |
| **PostgreSQL + pgvector** | Vector similarity search | 5433 |
| **Ollama Server** | Local LLM inference | 11435 |
| **Ollama WebUI** | Web interface for Ollama | 3011 |

## Ollama GPU Configuration

The Ollama service is configured with NVIDIA GPU support:

```yaml
ollama-server:
  image: ollama/ollama:latest
  runtime: nvidia
  environment:
    - NVIDIA_VISIBLE_DEVICES=all
```

### Pull Models for GPU
```bash
docker exec -it ollama-server-arxiv ollama pull llama3.2
docker exec -it ollama-server-arxiv ollama pull nomic-embed-text
```

### List Available Models
```bash
docker exec -it ollama-server-arxiv ollama list
```

## Data Persistence

All services use Docker volumes for data persistence:

| Service | Volume Location |
|---------|----------------|
| Neo4j | `./data/neo4j/` |
| PostgreSQL | `./data/postgres/` |
| Ollama | `${OLLAMA_PATH}/ollama_data` |

## Troubleshooting

### Ollama Not Using GPU

1. Verify NVIDIA runtime is configured:
   ```bash
   docker_default nvidia
   docker info | grep -i runtime
   ```

2. Check nvidia-smi inside container:
   ```bash
   docker exec -it ollama-server-arxiv nvidia-smi
   ```

3. Restart Ollama service:
   ```bash
   docker compose restart ollama-server
   ```

### Service Connection Issues

Verify services are running:
```bash
docker compose ps
```

Check logs for errors:
```bash
docker compose logs neo4j
docker compose logs postgres
```

### Clean Up and Rebuild
```bash
docker compose down -v
docker compose up -d --build
```

## Environment Variables

All variables used in docker should be in the .env.

## Code Examples

### Running Ollama with GPU in Python
```python
import requests

OLLAMA_URL = "http://localhost:11435/api/generate"

def generate_with_ollama(prompt: str, model: str = "llama3.2") -> str:
    response = requests.post(
        OLLAMA_URL,
        json={
            "model": model,
            "prompt": prompt,
            "stream": False
        }
    )
    return response.json()["response"]
```

### Connecting to PostgreSQL
```python
import psycopg2

conn = psycopg2.connect(
    host="localhost",
    port="5433",
    database="arxiv",
    user="postgres",
    password="postgres"
)
```

### Connecting to Neo4j
```python
from neo4j import GraphDatabase

driver = GraphDatabase.driver(
    "bolt://localhost:7688",
    auth=("neo4j", "your_password")
)
```

## Important Notes

1. **Always run `docker_default nvidia` before starting services** if you want GPU support for Ollama.

2. The `docker_default` command must be run in the shell where you'll execute docker commands.

3. GPU memory requirements vary by model. Ensure your GPU has enough VRAM.

4. The Ollama WebUI is accessible at http://localhost:3011

5. Neo4j Browser is accessible at http://localhost:7475