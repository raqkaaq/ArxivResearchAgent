# RAG Orchestrator Skill

This skill encapsulates RAG nodes for hybrid retrieval-augmented generation in Orchestral AI graphs, including vector search with PostgreSQL/pgvector, knowledge graph traversal with Neo4j, and agentic grading/rewriting.

## Features
- Retrieve node with PostgreSQL/pgvector integration for embedding-based similarity.
- Knowledge graph traversal (PageRank, centrality, shortest path) with Neo4j.
- HyDE (Hypothetical Document Embeddings) for better document matching.
- Grading and rewriting nodes for iterative refinement.
- Hybrid ranking combining vector and graph results.

## Usage
Load for RAG implementation in Orchestral AI agents. Provides pre-built nodes for hybrid retrieval pipelines combining PostgreSQL vectors and Neo4j graph relationships.

## Implementation
- Based on RAG_PRD.md hybrid RAG design.
- Supports vector + graph hybrid retrieval.
- Integrates with Ollama/Gemini for embeddings and generation.

## Code Examples
From Hybrid RAG design:

```python
from orchestral_ai import Graph, AgentNode, Command
from typing import TypedDict, List, Literal

# RAG state definition
class RAGState(TypedDict):
    query: str
    docs: List[dict]
    filtered_docs: List[dict]
    relevance_scores: List[float]

# Hybrid retrieve node
def retrieve(state: RAGState) -> Command[Literal["grade", "rewrite"]]:
    query = state["query"]
    
    # Vector search with PostgreSQL/pgvector
    vector_results = pgvector_search(query, k=10)
    
    # Graph traversal with Neo4j
    graph_results = neo4j_traverse(query, depth=2)
    
    # Hybrid ranking
    hybrid_docs = hybrid_rank(vector_results, graph_results)
    
    return Command(update={"docs": hybrid_docs}, goto="grade")

# Grade node
def grade_documents(state: RAGState) -> Command[Literal["generate", "rewrite"]]:
    docs = state["docs"]
    
    # LLM grading for relevance
    graded = []
    for doc in docs:
        score = llm_grade(state["query"], doc)
        if score > 0.7:
            graded.append({**doc, "relevance": score})
    
    if graded:
        return Command(update={"filtered_docs": graded}, goto="generate")
    else:
        return Command(goto="rewrite")

# Build graph
graph = Graph(
    nodes=[
        AgentNode(name="retrieve", retrieve),
        AgentNode(name="grade", grade_documents),
        AgentNode(name="generate", generate_response),
    ]
)
```

## Integration Points
- **Pre-Agent Mode**: Standalone chain for quick, direct retrieval and generation.
- **Agent Tool Mode**: Integrated into Orchestral AI graphs for iterative, multi-step reasoning.
- **CLI Subgraph**: Used in hybrid_rag_node for user research queries.
- **Automator Subgraph**: Used in similarity_node for comparing papers to liked embeddings.

## Neo4j Graph Algorithms
- **PageRank**: Ranks nodes by importance based on incoming links (citations).
- **Centrality**: Measures node influence (degree, betweenness).
- **Shortest Path**: Finds related papers via minimal citation hops.