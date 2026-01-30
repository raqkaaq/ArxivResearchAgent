# RAG Product Requirements Document: Graph-Enhanced Agentic RAG for Arxiv Research Agent

## Overview
This PRD details the "Hybrid Retrieval Augmented Generation" system, a sophisticated framework combining vector-based retrieval (via PostgreSQL with pgvector), knowledge graph reasoning (for structured relations like citations via Neo4j), and hierarchical multi-agent orchestration (via LangGraph) to enable deep, faithful reasoning for Arxiv paper queries. The system addresses limitations of vanilla RAG (e.g., surface-level similarity) by modeling domain-specific relations and enabling agentic adaptation.

The RAG works in two modes:
- **Pre-Agent**: A standalone chain for quick, direct retrieval and generation.
- **Agent Tool**: Integrated into LangGraph graphs for iterative, multi-step reasoning in the CLI chatbot and user-triggered automator.

This design ensures robustness, scalability, and alignment with Arxiv's citation-heavy ecosystem, enhancing the overall research agent.

## Key Research Papers and Inspirations
This system draws from cutting-edge Arxiv papers (2024-2025) on advanced RAG, focusing on graph-based and agentic enhancements for improved reasoning and faithfulness:

- **Think-on-Graph 2.0: Deep and Faithful Large Language Model Reasoning with Knowledge-guided Retrieval Augmented Generation** (Arxiv 2407.10805, 2024-2025): Core inspiration for knowledge-guided graph reasoning. It uses graphs to model entity relations (e.g., paper citations, co-authorship) during retrieval, enabling "deep and faithful" generation by conditioning on structured knowledge. Applied here to Arxiv's relational data for better similarity and reasoning.
  
- **HM-RAG: Hierarchical Multi-Agent Multimodal Retrieval Augmented Generation** (Arxiv 2504.12330, 2025): Inspiration for hierarchical multi-agent architecture. It coordinates sub-agents across heterogeneous data for complex queries. Used to structure the agentic layer, allowing supervisor routing and collaborative reasoning in the RAG graph.

Additional context from surveys:
- **Retrieval-Augmented Generation: A Comprehensive Survey of Architectures, Enhancements, and Robustness Frontiers** (Arxiv 2506.00054, 2025): Highlights gaps in multimodal and robustness; this system addresses text-domain robustness via graphs and agents.
- **A Systematic Review of Key Retrieval-Augmented Generation (RAG) Systems** (Arxiv 2507.18910, 2025): Emphasizes agentic and hybrid approaches for industry; informs the dual-mode design.

These papers provide empirical backing for graph-agent hybrids, outperforming vector-only RAG in depth and fidelity.

## Core Architecture
The RAG is a hybrid system with three pillars:
- **Vector Retrieval**: PostgreSQL with pgvector for embedding-based similarity (using Ollama/Gemini).
- **Knowledge Graph**: Neo4j for graph-based relationship modeling and relationship traversal (papers, authors, citations).
- **Agentic Orchestration**: LangGraph for hierarchical agents (supervisor + sub-agents) handling reasoning and routing.

Components integrate via APIs, with fallbacks for robustness.

```mermaid
graph TD
    A[User Query] --> B[Input Processing]
    B --> C[Vector Retrieval - PostgreSQL]
    B --> D[Graph Traversal - Neo4j]
    C --> E[Hybrid Ranking]
    D --> E
    E --> F[Agentic Layer - LangGraph]
    F --> G[Supervisor Agent]
    G --> H[Retrieval Sub-Agent]
    G --> I[Reasoning Sub-Agent]
    H --> J[Final Generation]
    I --> J
    J --> K[Response]
```

- **Vector Retrieval (PostgreSQL/pgvector)**: Embeds and stores paper abstracts; performs semantic search.
- **Knowledge Graph (Neo4j)**: Models relations; queries for connected entities.
- **Agentic Layer (LangGraph)**: Nodes for grading, rewriting; edges for conditional flow.
- **Integration**: Shared state across components; LLMs (Ollama primary) for generation/grading.

## Runtime Flow
The flow adapts based on mode and query complexity, with conditional routing for efficiency.

### Pre-Agent Mode (Standalone Chain)
For simple queries: Retrieve → Generate.
```mermaid
flowchart TD
    A[User Query] --> B[Embed Query]
    B --> C[Hybrid Search: Vector + Graph]
    C --> D[Rank & Format Docs]
    D --> E[LLM Generation]
    E --> F[Response]
```

### Agent Tool Mode (LangGraph Graph)
For complex queries: Full reasoning with agents.
```mermaid
flowchart TD
    A[Query] --> B[Input Node: Validate & HyDE]
    B --> C[Retrieve Node: Hybrid Search]
    C --> D[Grade Node: LLM Scores Docs]
    D --> DocsRelevant?
    DocsRelevant? -->|Yes| E[Reasoning Node: Agent Plans]
    DocsRelevant? -->|No| F[Rewrite Node: LLM Rephrases]
    F --> C
    E --> G[Generate Node: Synthesize]
    G --> H[Correct Node: Check Grounding]
    H --> Grounded?
    Grounded? -->|Yes| I[Output Node: Response]
    Grounded? -->|No| F
    I --> J[Log Metrics]
```

- **Key Flows**: Conditional edges (e.g., retry on low relevance); agents handle multi-step (e.g., reasoning sub-agent for citations).
- **Error Handling**: Retries for API failures; interrupts for graph issues.
- **Performance**: Async for retrieval; max 3 rewrites to avoid loops.

## Components and Features
- **Vector Retrieval**: PostgreSQL with pgvector and Ollama embeddings; hybrid (semantic + keyword).
- **Knowledge Graph**: Neo4j for graphs; key algorithms:
  - **PageRank**: Ranks nodes by importance based on incoming links (citations). Iteratively calculates scores—higher for nodes linked by influential others. Used to rank retrieved papers by citation influence.
  - **Centrality**: Measures node influence (e.g., degree for connections, betweenness for bridges in citation networks).
  - **Shortest Path**: Finds related papers via minimal citation hops. Nodes (papers/authors), edges (citations).
- **Agentic Layer**: Supervisor routes to sub-agents (retrieval, reasoning); Command-based routing in LangGraph.
- **LLM Integration**: Ollama for local; Gemini fallback. Structured prompts for grading/rewriting.
- **Modes**:
  - Pre-Agent: LangGraph chain for fast responses.
  - Agent Tool: Full graph for adaptive reasoning.
- **Features**: 
  - Speculative drafting (LLM drafts response to guide retrieval).
  - HyDE (Hypothetical Document Embeddings—generate hypothetical answer via LLM, embed for better document matching).
  - Cascading grading (multi-stage relevance checks).
  - Multimodal-ready (extend for figures).

## Requirements and Tradeoffs
- **Functional**: Retrieve Arxiv papers via vectors/graphs; generate faithful answers; classify/ingest via agents.
- **Non-Functional**: Scalability (1000+ papers); latency (<5s for retrieval); robustness (handle noisy metadata).
- **Dependencies**: langgraph, psycopg2-binary, neo4j, pgvector, arxiv, requests, tenacity.
- **Tradeoffs**:
  - Neo4j adds depth with persistent graph storage (data preserved across restarts).
  - Agents improve reasoning but increase latency; limit to complex queries.
  - Vector-only fallback if graph sparse.

## Integration with Arxiv Agent
- **CLI**: Pre-agent for "research X" (direct answer). Agent tool: In hybrid_rag_node, call RAG graph if query needs retrieval.
- **Automator**: Agent tool in similarity_node (retrieve similar to liked embeddings for ingestion).
- **Ingestion**: On new papers, embed abstracts; add to PostgreSQL with metadata; build Neo4j relationships.
- **Context Management**: PostgreSQL can be queried separately for retrieving compressed conversation history. See CONTEXT_PRD.md for details.

## Implementation Roadmap
1. Setup: Init PostgreSQL with pgvector, Neo4j, Ollama.
2. Core: Build hybrid retrieval, graph agents.
3. Integration: Plug into CLI/automator.
4. Testing: Evaluate hybrid RAG queries and Neo4j relationship traversals on Arxiv data.
5. Iteration: Optimize performance and add advanced fusion algorithms.

## TUI Integration for RAG Results

### Research Explorer Interface
The RAG system integrates with the TUI Research Explorer for interactive paper discovery:

```python
# TUI research explorer for RAG results
class ResearchExplorer:
    """Interactive paper discovery through TUI"""
    
    def __init__(self, rag_system: HybridRAG):
        self.rag = rag_system
        self.results_per_page = 10
        
    async def search_and_display(self, query: str):
        """Search via RAG and display progressively"""
        results = await self.rag.hybrid_search(query)
        
        for i, paper in enumerate(results[:50]):
            self.display_paper_details(paper, page=i // self.results_per_page + 1)
            
    def display_paper_details(self, paper: dict, page: int):
        """Show paper with citations, authors, relevance score"""
        # Display from Neo4j graph data
        citations = self.rag.neo4j.get_citations(paper['id'])
        authors = self.rag.neo4j.get_authors(paper['id'])
        
        self.tui.add_panel(f"Page {page}: {paper['title']}")
        self.tui.add_panel(f"Authors: {', '.join(authors)}")
        self.tui.add_panel(f"Citations: {len(citations)}")
        self.tui.add_panel(f"Relevance: {paper['score']:.2f}")
```

### Network Visualization
The RAG system provides citation network data for the TUI Network Visualizer:

```python
# Network visualization integration
class NetworkVisualizer:
    """Citation network display from RAG graph data"""
    
    def __init__(self, neo4j_connection):
        self.neo4j = neo4j_connection
        
    def get_network_for_paper(self, paper_id: str, depth: int = 2):
        """Get citation network up to specified depth"""
        return self.neo4j.traverse_network(paper_id, max_depth=depth)
```

This RAG elevates the agent with paper-inspired sophistication. Reference PRD.md for overall system integration.