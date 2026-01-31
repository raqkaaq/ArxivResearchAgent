# Database Integration Patterns for LangGraph

This guide covers best practices for integrating various databases with LangGraph agents, including SQL (PostgreSQL), NoSQL (Neo4j), and vector databases for hybrid retrieval and storage patterns.

## Table of Contents

1. [Core Integration Patterns](#core-integration-patterns)
2. [PostgreSQL Integration](#postgresql-integration)
3. [Neo4j Integration](#neo4j-integration)
4. [Vector Database Integration](#vector-database-integration)
5. [Hybrid Storage Patterns](#hybrid-storage-patterns)
6. [Connection Management](#connection-management)
7. [Error Handling](#error-handling)
8. [Performance Optimization](#performance-optimization)
9. [Security Considerations](#security-considerations)

## Core Integration Patterns

### State-Based Database Connections

For LangGraph agents, database connections should be managed through the shared state to ensure proper lifecycle management and reuse across nodes.

```python
from typing import TypedDict
from psycopg2 import connect
from neo4j import GraphDatabase

class DatabaseState(TypedDict):
    postgres_client: object | None
    neo4j_driver: object | None
    vector_db_client: object | None
    connection_pool: dict | None
```

### Node-Based Database Operations

Database operations should be encapsulated in dedicated nodes to maintain separation of concerns and enable proper error handling.

```python
def connect_postgres_node(state: DatabaseState):
    if state.get("postgres_client") is None:
        postgres_client = connect(
            dbname="research_db",
            user="research_user",
            password="secure_password",
            host="localhost",
            port=5432
        )
        return {"postgres_client": postgres_client}
    return {}

def disconnect_postgres_node(state: DatabaseState):
    if state.get("postgres_client") is not None:
        state["postgres_client"].close()
        return {"postgres_client": None}
    return {}
```

## PostgreSQL Integration

### Connection Patterns

#### Direct Connection
```python
def connect_postgres_direct(state: DatabaseState):
    client = psycopg2.connect(
        dbname="research_db",
        user="research_user",
        password="secure_password",
        host="localhost",
        port=5432
    )
    return {"postgres_client": client}
```

#### Connection Pooling
```python
def connect_postgres_pool(state: DatabaseState):
    from psycopg2 import pool
    
    connection_pool = pool.SimpleConnectionPool(
        1, 20,
        user="research_user",
        password="secure_password",
        host="localhost",
        port=5432,
        database="research_db"
    )
    return {"connection_pool": connection_pool}
```

### Query Patterns

#### Simple Query Node
```python
def query_papers_node(state: DatabaseState):
    query = """
    SELECT id, title, abstract, published_date
    FROM papers
    WHERE published_date > %s
    ORDER BY published_date DESC
    LIMIT 10
    """
    
    cursor = state["postgres_client"].cursor()
    cursor.execute(query, (state.get("start_date", "2023-01-01"),))
    papers = cursor.fetchall()
    
    return {"recent_papers": papers}
```

#### Parameterized Query Node
```python
def search_papers_node(state: DatabaseState):
    query = """
    SELECT id, title, abstract, published_date
    FROM papers
    WHERE title ILIKE %s OR abstract ILIKE %s
    ORDER BY published_date DESC
    LIMIT 20
    """
    
    search_term = f"%{state.get('search_query', '')}%"
    cursor = state["postgres_client"].cursor()
    cursor.execute(query, (search_term, search_term))
    papers = cursor.fetchall()
    
    return {"search_results": papers}
```

## Neo4j Integration

### Connection Patterns

#### Bolt Connection
```python
def connect_neo4j_bolt(state: DatabaseState):
    driver = GraphDatabase.driver(
        "bolt://localhost:7687",
        auth=("neo4j", "password"),
        encrypted=True
    )
    return {"neo4j_driver": driver}
```

#### Session Management
```python
def query_neo4j_session(state: DatabaseState):
    with state["neo4j_driver"].session() as session:
        result = session.read_transaction(lambda tx: 
            tx.run("MATCH (p:Paper) RETURN p LIMIT 10").data()
        )
    return {"neo4j_results": result}
```

### Cypher Query Patterns

#### Simple Pattern Matching
```python
def find_related_papers_node(state: DatabaseState):
    query = """
    MATCH (p:Paper {id: $paper_id})-[r:RELATED_TO]->(related:Paper)
    RETURN related, r.weight AS similarity
    ORDER BY similarity DESC
    LIMIT 10
    """
    
    with state["neo4j_driver"].session() as session:
        result = session.read_transaction(lambda tx: 
            tx.run(query, paper_id=state.get("paper_id")).data()
        )
    
    return {"related_papers": result}
```

#### Complex Graph Traversal
```python
def find_collaboration_paths_node(state: DatabaseState):
    query = """
    MATCH path = (author1:Author)-[:CO_AUTHORED]->(paper:Paper)<-[:CO_AUTHORED]-(author2:Author)
    WHERE author1.name = $author_name
    RETURN path, length(path) AS path_length
    ORDER BY path_length ASC
    LIMIT 5
    """
    
    with state["neo4j_driver"].session() as session:
        result = session.read_transaction(lambda tx: 
            tx.run(query, author_name=state.get("author_name")).data()
        )
    
    return {"collaboration_paths": result}
```

## Vector Database Integration

### Embedding Storage Patterns

#### Vector Insertion
```python
def store_paper_embedding_node(state: DatabaseState):
    embedding = generate_embedding(state["paper_abstract"])
    
    # Using FAISS or similar vector database
    index = state.get("vector_index")
    index.add_with_ids(
        [embedding],
        [state.get("paper_id")]
    )
    
    return {"vector_index": index}
```

#### Similarity Search
```python
def find_similar_papers_node(state: DatabaseState):
    query_embedding = generate_embedding(state["query_text"])
    
    index = state.get("vector_index")
    distances, ids = index.search([query_embedding], k=10)
    
    return {
        "similar_paper_ids": ids[0],
        "similarities": distances[0]
    }
```

## Hybrid Storage Patterns

### Multi-Database Retrieval

#### PostgreSQL + Neo4j Hybrid Query
```python
def hybrid_paper_search_node(state: DatabaseState):
    # Step 1: Search PostgreSQL for metadata
    postgres_query = """
    SELECT id, title, abstract, published_date
    FROM papers
    WHERE title ILIKE %s OR abstract ILIKE %s
    LIMIT 20
    """
    
    search_term = f"%{state.get('search_query', '')}%"
    cursor = state["postgres_client"].cursor()
    cursor.execute(postgres_query, (search_term, search_term))
    postgres_results = cursor.fetchall()
    
    # Step 2: Get graph relationships from Neo4j
    with state["neo4j_driver"].session() as session:
        cypher_query = """
        MATCH (p:Paper)
        WHERE p.id IN $paper_ids
        RETURN p.id AS paper_id, 
               [(p)-[r:RELATED_TO]->(related) | [related.id, r.weight]] AS related
        """
        
        paper_ids = [row[0] for row in postgres_results]
        neo4j_results = session.read_transaction(lambda tx: 
            tx.run(cypher_query, paper_ids=paper_ids).data()
        )
    
    # Combine results
    combined_results = []
    for postgres_row in postgres_results:
        paper_id = postgres_row[0]
        related = next(
            (item["related"] for item in neo4j_results if item["paper_id"] == paper_id),
            []
        )
        combined_results.append({
            "metadata": postgres_row,
            "related": related
        })
    
    return {"hybrid_search_results": combined_results}
```

### Vector + Graph Hybrid

#### Semantic Search with Graph Context
```python
def semantic_graph_search_node(state: DatabaseState):
    # Step 1: Vector similarity search
    query_embedding = generate_embedding(state["query_text"])
    distances, ids = state["vector_index"].search([query_embedding], k=20)
    
    # Step 2: Get graph context for top results
    with state["neo4j_driver"].session() as session:
        cypher_query = """
        MATCH (p:Paper)
        WHERE p.id IN $paper_ids
        RETURN p.id AS paper_id, 
               p.title AS title,
               p.abstract AS abstract,
               [(p)-[r:RELATED_TO]->(related) | [related.id, r.weight]] AS related,
               [(p)-[:AUTHORED_BY]->(author) | author.name] AS authors
        ORDER BY p.published_date DESC
        """
        
        graph_results = session.read_transaction(lambda tx: 
            tx.run(cypher_query, paper_ids=ids[0]).data()
        )
    
    # Step 3: Rank by combining semantic and graph similarity
    ranked_results = []
    for i, paper_id in enumerate(ids[0]):
        graph_data = next(
            (item for item in graph_results if item["paper_id"] == paper_id),
            None
        )
        if graph_data:
            # Combine semantic distance with graph connectivity
            semantic_score = 1 - distances[0][i]  # Convert distance to similarity
            graph_score = len(graph_data.get("related", [])) * 0.1
            combined_score = semantic_score + graph_score
            
            ranked_results.append({
                "paper_id": paper_id,
                "title": graph_data["title"],
                "abstract": graph_data["abstract"],
                "authors": graph_data["authors"],
                "related": graph_data["related"],
                "semantic_score": semantic_score,
                "graph_score": graph_score,
                "combined_score": combined_score
            })
    
    # Sort by combined score
    ranked_results.sort(key=lambda x: x["combined_score"], reverse=True)
    
    return {"hybrid_ranked_results": ranked_results}
```

## Connection Management

### Lifecycle Management

#### Initialize Connections
```python
def initialize_database_connections_node(state: DatabaseState):
    # Initialize PostgreSQL
    postgres_client = psycopg2.connect(
        dbname="research_db",
        user="research_user",
        password="secure_password",
        host="localhost",
        port=5432
    )
    
    # Initialize Neo4j
    neo4j_driver = GraphDatabase.driver(
        "bolt://localhost:7687",
        auth=("neo4j", "password"),
        encrypted=True
    )
    
    # Initialize Vector Database (FAISS example)
    import faiss
    vector_index = faiss.IndexFlatL2(768)  # For 768-dimensional embeddings
    
    return {
        "postgres_client": postgres_client,
        "neo4j_driver": neo4j_driver,
        "vector_index": vector_index
    }
```

#### Cleanup Connections
```python
def cleanup_database_connections_node(state: DatabaseState):
    # Close PostgreSQL connection
    if state.get("postgres_client") is not None:
        state["postgres_client"].close()
    
    # Close Neo4j driver
    if state.get("neo4j_driver") is not None:
        state["neo4j_driver"].close()
    
    # Clean up vector index
    if state.get("vector_index") is not None:
        del state["vector_index"]
    
    return {
        "postgres_client": None,
        "neo4j_driver": None,
        "vector_index": None
    }
```

### Connection Pooling

#### Database Connection Pool
```python
def manage_connection_pool_node(state: DatabaseState):
    from psycopg2 import pool
    from neo4j import GraphDatabase
    
    if state.get("connection_pool") is None:
        # Create connection pools
        postgres_pool = pool.SimpleConnectionPool(
            1, 20,
            user="research_user",
            password="secure_password",
            host="localhost",
            port=5432,
            database="research_db"
        )
        
        neo4j_pool = []  # Simple list-based pool for Neo4j
        
        return {
            "connection_pool": {
                "postgres": postgres_pool,
                "neo4j": neo4j_pool,
                "vector": None  # Vector databases typically don't use pooling
            }
        }
    
    return {}
```

## Error Handling

### Database Connection Errors

#### Retry Logic
```python
def connect_with_retry_node(state: DatabaseState):
    import time
    from psycopg2 import OperationalError
    
    max_retries = 3
    retry_delay = 2  # seconds
    
    for attempt in range(max_retries):
        try:
            client = psycopg2.connect(
                dbname="research_db",
                user="research_user",
                password="secure_password",
                host="localhost",
                port=5432
            )
            return {"postgres_client": client}
        except OperationalError as e:
            if attempt == max_retries - 1:
                raise Exception(f"Failed to connect to database after {max_retries} attempts")
            time.sleep(retry_delay * (attempt + 1))
    
    return {}
```

### Query Error Handling

#### Graceful Degradation
```python
def query_with_fallback_node(state: DatabaseState):
    try:
        # Try PostgreSQL first
        cursor = state["postgres_client"].cursor()
        cursor.execute("SELECT * FROM papers LIMIT 10")
        results = cursor.fetchall()
        return {"query_results": results, "source": "postgres"}
    except Exception as e:
        # Fallback to Neo4j if PostgreSQL fails
        try:
            with state["neo4j_driver"].session() as session:
                result = session.read_transaction(lambda tx: 
                    tx.run("MATCH (p:Paper) RETURN p LIMIT 10").data()
                )
            return {"query_results": result, "source": "neo4j"}
        except Exception as fallback_error:
            return {"query_results": [], "error": str(fallback_error), "source": "none"}
```

## Performance Optimization

### Query Optimization

#### Indexing Strategies
```python
def ensure_indexes_node(state: DatabaseState):
    # PostgreSQL indexes
    index_queries = [
        "CREATE INDEX IF NOT EXISTS idx_papers_title ON papers USING gin(title gin_trgm_ops)",
        "CREATE INDEX IF NOT EXISTS idx_papers_abstract ON papers USING gin(abstract gin_trgm_ops)",
        "CREATE INDEX IF NOT EXISTS idx_papers_date ON papers(published_date)",
        "CREATE INDEX IF NOT EXISTS idx_papers_authors ON papers USING gin(authors)",
    ]
    
    cursor = state["postgres_client"].cursor()
    for query in index_queries:
        cursor.execute(query)
    
    # Neo4j indexes
    with state["neo4j_driver"].session() as session:
        session.write_transaction(lambda tx: [
            tx.run("CREATE INDEX IF NOT EXISTS FOR (p:Paper) ON (p.id)"),
            tx.run("CREATE INDEX IF NOT EXISTS FOR (p:Paper) ON (p.title)"),
            tx.run("CREATE INDEX IF NOT EXISTS FOR (a:Author) ON (a.name)")
        ])
    
    return {"indexes_ensured": True}
```

### Caching Strategies

#### Query Result Caching
```python
def cache_query_results_node(state: DatabaseState):
    from functools import lru_cache
    import hashlib
    
    @lru_cache(maxsize=100)
    def cached_query(query_hash: str):
        # Execute actual query
        cursor = state["postgres_client"].cursor()
        cursor.execute("SELECT * FROM papers WHERE query_hash = %s", (query_hash,))
        return cursor.fetchall()
    
    # Generate hash for current query
    query_params = state.get("query_params", {})
    query_hash = hashlib.sha256(str(query_params).encode()).hexdigest()
    
    results = cached_query(query_hash)
    
    return {"cached_results": results}
```

## Security Considerations

### Credential Management

#### Environment Variables
```python
def load_database_credentials_node(state: DatabaseState):
    import os
    
    credentials = {
        "postgres": {
            "dbname": os.getenv("POSTGRES_DB", "research_db"),
            "user": os.getenv("POSTGRES_USER", "research_user"),
            "password": os.getenv("POSTGRES_PASSWORD", ""),
            "host": os.getenv("POSTGRES_HOST", "localhost"),
            "port": int(os.getenv("POSTGRES_PORT", "5432"))
        },
        "neo4j": {
            "uri": os.getenv("NEO4J_URI", "bolt://localhost:7687"),
            "user": os.getenv("NEO4J_USER", "neo4j"),
            "password": os.getenv("NEO4J_PASSWORD", "password")
        }
    }
    
    return {"database_credentials": credentials}
```

### Connection Security

#### SSL/TLS Configuration
```python
def secure_database_connections_node(state: DatabaseState):
    # PostgreSQL SSL
    import ssl
    
    ssl_context = ssl.create_default_context(
        cafile="path/to/ca-cert.pem",
        capath="path/to/ca-certs/",
        cadata=None
    )
    
    # Neo4j encryption
    neo4j_driver = GraphDatabase.driver(
        "bolt://localhost:7687",
        auth=("neo4j", "password"),
        encrypted="REQUIRED",
        trust=Trust.ON_FIRST_USE,
        ssl_context=ssl_context
    )
    
    return {"neo4j_driver": neo4j_driver, "ssl_context": ssl_context}
```

## Best Practices

### Database Selection Guidelines

1. **Use PostgreSQL for**:
   - Structured metadata and tabular data
   - Complex queries with joins and aggregations
   - ACID transactions and data integrity
   - Large-scale data warehousing

2. **Use Neo4j for**:
   - Relationship-heavy data and graph patterns
   - Social networks and recommendation systems
   - Pathfinding and network analysis
   - Schema-flexible data models

3. **Use Vector Databases for**:
   - Semantic similarity search
   - RAG (Retrieval-Augmented Generation)
   - High-dimensional data indexing
   - Approximate nearest neighbor search

### Performance Monitoring

#### Query Performance Tracking
```python
def monitor_query_performance_node(state: DatabaseState):
    import time
    
    start_time = time.time()
    
    # Execute query
    cursor = state["postgres_client"].cursor()
    cursor.execute("SELECT * FROM papers WHERE published_date > %s", ("2023-01-01",))
    results = cursor.fetchall()
    
    execution_time = time.time() - start_time
    
    # Log performance
    with open("query_performance.log", "a") as log_file:
        log_file.write(f"Query executed in {execution_time:.4f} seconds\n")
    
    return {"query_results": results, "execution_time": execution_time}
```

### Scaling Considerations

#### Horizontal Scaling
```python
def scale_database_connections_node(state: DatabaseState):
    # PostgreSQL connection pool scaling
    from psycopg2 import pool
    
    # Increase pool size based on load
    current_pool = state.get("connection_pool")
    if current_pool:
        postgres_pool = current_pool.get("postgres")
        if postgres_pool:
            # Dynamically adjust pool size
            postgres_pool._maxconnections = 50  # Increase max connections
    
    return {"connection_pool": current_pool}
```

## Conclusion

Database integration with LangGraph requires careful consideration of connection management, error handling, performance optimization, and security. By following these patterns and best practices, you can build robust, scalable agents that effectively leverage multiple database systems for complex research and analysis workflows.

The key is to maintain clean separation of concerns, use state-based connection management, implement proper error handling and retry logic, and optimize queries for performance while ensuring data security and integrity.