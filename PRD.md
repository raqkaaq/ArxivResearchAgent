# Product Requirements Document (PRD): Arxiv Research Agent

## Overview
The Arxiv Research Agent is a dynamic, multiagent AI system built with **LangGraph** for researching, downloading, and compiling important details from Arxiv publications. It consists of two main components: a user-interactive CLI chatbot for querying and managing research, and a user-triggered automator for proactive ingestion and classification of recent papers. The system uses Ollama (primary) or Gemini (configurable fallback) for LLM tasks, PostgreSQL (with pgvector) for embedding-based RAG retrieval and heavy data storage, Neo4j for graph-based relationship analysis and RAG with analytics capabilities, SQLite for user feedback storage, and local file storage for papers.

The agent intelligently identifies and prioritizes papers based on user preferences ("likes") and relevance, storing key analytics without overwhelming the system. All tasks are well-logged for auditing.

## Goals
- **Primary**: Enable users to interactively research Arxiv papers via a chatbot, retrieve relevant information, and manage a personalized research database.
- **Secondary**: Provide a user-triggered mechanism to automatically pull, analyze, and store recent Arxiv papers that align with user interests, keeping the database updated without manual effort.
- **Non-Goals**: Real-time notifications, full-text paper analysis beyond metadata/abstracts, or integration with non-Arxiv sources.

## Key Features
- **CLI Chatbot**:
  - Accept natural language queries (e.g., "research quantum computing" or "show my liked papers").
  - Perform RAG-based retrieval from stored papers using embeddings. (See RAG_PRD.md for detailed RAG system design, including architecture diagrams and inspirations from modern papers.)
  - Initiate on-demand research (search/fetch Arxiv).
  - Allow users to "like" papers, updating similarity baselines.
  - Generate conversational responses with compiled details (title, authors, abstract, etc.).
  - **TUI Interface**: Modern terminal-based user interface with Textual, featuring:
    - **Chat Page**: Interactive research queries with progressive result display and paper details
    - **Papers Page**: Browse, search, and manage liked papers with "like" ratings
    - **Automator Page**: Real-time ingestion progress, classification status, and network visualization
    - **Metrics Page**: Real-time system monitoring (DB stats, query rates, storage usage)
    - Navigation via keyboard shortcuts, async updates, and clear feedback
   - **Progressive Analytics Dashboard**: Real-time display of ingestion progress, citation network statistics, author collaboration metrics, and system health monitoring.
- **TUI Metrics Dashboard**: Real-time metrics display using logs and runtime data, including:
      - Database statistics (PostgreSQL paper count, SQLite session count, Neo4j nodes/edges)
      - Query rates and latency metrics (retrieval time, RAG generation time)
      - Storage usage (papers/ directory size, log file sizes)
      - Automator progress (papers processed, classification distribution)
      - System health (LLM availability, API connectivity)
- **User-Triggered Automator**:
   - Pull recent Arxiv papers (e.g., last 24-48 hours).
   - Embed papers and compare to user-liked baselines for similarity.
   - Classify importance using LLM (1-10 score based on novelty, impact, relevance), with data from Semantic Scholar (citations/h-index) or Arxiv (metadata) for training.
   - Store high-importance papers (embeddings in PostgreSQL, metadata in SQLite, graph relationships in Neo4j, downloads in papers/ directory).
   - Prune old/unimportant data to manage storage.
- **Shared Infrastructure**:
   - PostgreSQL (with pgvector) for vector search, similarity matching, and heavy data storage.
   - Neo4j for citation networks, knowledge graph operations, graph-based RAG, and analytics.
   - SQLite for user feedback ("likes") and structured metadata.
   - Paper Storage (papers/ directory) for selective PDF/source downloads.
   - Logging (logs/ directory) with structured JSON logs for actions, errors, and metrics.
   - Context Management: Adaptive compression for long conversations with dynamic token thresholds based on LLM. (See CONTEXT_PRD.md for detailed system design, including architecture diagrams and inspirations from modern papers.)
   - LLM Config: Ollama for local inference; Gemini for API-based fallback/scalability.
- **Intelligence & Dynamics**:
   - Similarity-based filtering: Use cosine similarity on embeddings (PostgreSQL/pgvector) and graph relationships (Neo4j) to find papers "similar to liked ones."
  - Adaptive Classification: LLM evaluates papers for importance, considering user context.
  - Selective Downloads: Only download top-scoring papers to avoid storage bloat.
  - Error Handling: Retries for API failures, interrupts for config issues, detailed logging.

## Architecture
- **Tech Stack**:
   - **LangGraph**: For multiagent orchestration with graph-based state management.
   - **Arxiv SDK** (arxiv.py): For searching, fetching metadata.
   - **Semantic Scholar SDK** (external): For citations, h-index, paper counts, and downloading.
   - **PostgreSQL with pgvector**: Vector database for embeddings and semantic similarity (shared with RAG).
   - **Neo4j**: Graph database for citation networks, knowledge graph operations, graph-based RAG, and analytics.
   - **SQLite**: User feedback storage for "likes" and preferences (in db/sqlite/).
   - **LangChain Community**: For LLM integration, tools, and utilities.
   - **Python**: Core language (version dictated by conda env). (See RAG_PRD.md and CONTEXT_PRD.md for RAG and Context-specific components.)
- **Multiagent Structure**:
  - **Research Agent**: Main agent with tools for CLI interactions and automator operations.
  - **CLI Tools**: Handle user interactions (search_arxiv, fetch_metadata, store_paper, like_paper, get_liked_papers).
  - **Automator Tools**: Handle background ingestion (pull_recent_papers, embed_paper, classify_importance, store_paper, clean_old_papers).
- **State Management**:
   - **StateGraph**: LangGraph's StateGraph manages conversation history and state via TypedDict.
   - **Checkpointer**: SQLite-based checkpointing for state persistence across sessions.
   - **Shared State**: Database connections and user preferences passed via state schema.
   - **Persistence**: State saved/loaded via LangGraph checkpointer.
- **Data Flow**:
   - CLI: Query → Embed → Hybrid Search (PostgreSQL vectors + Neo4j graph) → Respond.
   - Automator: Pull Arxiv → Store PostgreSQL + Build Neo4j graph → Classify → Storage.
- **Deployment**: Local Python scripts; CLI via command-line (e.g., `python main.py --chat` or `python main.py --automate`).

## Requirements
- **Functional**:
   - Search Arxiv with queries/ID lists.
   - Fetch metadata (title, authors, summary, categories, links) or enriched data from Semantic Scholar (citations, h-index, paper counts).
   - Download PDFs/sources selectively.
   - Embed text for similarity search.
   - Classify papers with LLM scores.
   - Store and retrieve via hybrid storage (PostgreSQL + Neo4j + SQLite) with graph persistence.
   - Log all actions with timestamps/levels.
   - User feedback via SQLite for "likes" to personalize recommendations.
- **Non-Functional**:
   - Performance: Handle 100+ papers per run; hybrid RAG retrieval <3s; Neo4j graph query <1s.
   - Reliability: Retry on failures; graph consistency validation; log errors.
   - Security: No secrets in code; use env vars for API keys.
   - Usability: Simple CLI commands; clear responses; transparent hybrid query routing.
   - Scalability: Prune PostgreSQL tables and SQLite data; configurable limits (e.g., max papers=2000).
- **Dependencies**:
   - Python 3.11+.
   - Packages: langgraph, langchain-openai, langchain-anthropic, psycopg2-binary, neo4j, sqlite3, arxiv, requests, tenacity, diskcache, pgvector.
   - External Services: PostgreSQL, Neo4j, Ollama, Docker (optional).
   - Environment Configuration: .env for API keys (OLLAMA_BASE_URL, GEMINI_API_KEY, POSTGRES_URL, NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD).
   - (See DATA_PRD.md for Semantic Scholar SDK integration details.)
- **Assumptions**:
  - User has Ollama installed locally (via Docker or otherwise).
  - Server may not be always online (hence user-triggered automator).
  - Arxiv API rate limits respected (3s delay).
  - Semantic Scholar SDK provided externally.
  - Single-user system.
  - Latest package versions handled by user.
- **Constraints**:
  - No cronjobs; manual triggering.
  - Local-first; optional cloud LLM.

## User Stories
- As a researcher, I want to chat with the agent to find relevant papers, so I can discover new work quickly.
- As a user, I want to "like" papers to personalize recommendations, so the system learns my interests.
- As a user, I want to trigger automated ingestion, so my DB stays updated with recent, relevant papers.
- As a user, I want detailed logs, so I can audit what the agent did.

## Success Metrics
- CLI: Response accuracy (RAG retrieval relevance >80%).
- Automator: Ingestion efficiency (process 100 papers in <10min); classification accuracy (user agreement >70%).
- System: Uptime reliability (no crashes on retries); storage efficiency (DB size <1GB after pruning).

## Risks & Mitigations
- LLM Dependency: Ollama fallback to Gemini; test both.
- API Limits: Respect delays; batch requests.
- Storage Growth: Auto-prune old data.
- User Errors: Validate inputs; provide help commands.

## Timeline & Milestones
- Week 1: Finalize PRD (this doc) and cross-database architecture details.
- Week 2: Implement core agents and hybrid DB setup with coordination layer.
- Week 3: Integrate LLMs and hybrid RAG with query federation.
- Week 4: Testing cross-database consistency and performance optimization.
- Ongoing: Iterate based on user analytics, TUI interaction data, and progressive system monitoring.

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
```python
# Critical path: LangGraph import → PostgreSQL processing → Vector generation
arxiv_research_system/
├── agents/
│   ├── research_graph.py       # LangGraph StateGraph for research workflow
│   ├── automator_graph.py      # LangGraph StateGraph for ingestion
│   └── shared_state.py         # TypedDict state schema definitions
├── database/
│   ├── postgres_setup.py       # PostgreSQL initialization with pgvector
│   ├── neo4j_setup.py          # Neo4j graph schema
│   └── schemas.py              # Table definitions
├── embeddings/
│   ├── ollama_embeddings.py    # Local model for embeddings
│   └── embedding_manager.py    # Multi-strategy coordination
```

### Phase 2: Live Data Integration (Weeks 3-4)
```python
# Real-time updates and enrichment
arxiv_research_system/
├── live_data_integration/
│   ├── arxiv_streamer.py       # Continuous paper monitoring
│   ├── semantic_scholar_enricher.py  # Author metadata enhancement
│   ├── data_fusion.py           # Merge multiple data sources
│   └── update_coordinator.py    # Conflict resolution
├── agents/
│   ├── ingestion_agent.py       # LangGraph agent for paper processing
│   └── enrichment_agent.py      # LangGraph agent for analytics
```

### Phase 3: Advanced Features (Weeks 5-6)
```python
# TUI and advanced analytics
arxiv_research_system/
├── tui/
│   ├── dashboard.py             # Real-time metrics display
│   ├── research_explorer.py     # Interactive paper discovery
│   ├── network_visualizer.py    # Citation network display
│   └── user_preferences.py      # Custom settings management
├── analytics/
│   ├── trend_analyzer.py        # Topic evolution tracking
│   ├── breakthrough_detector.py # Impact paper identification
│   └── collaboration_analyzer.py # Research network analysis
```

## Data Sources Confirmed
1. **HuggingFace Dataset**: Initial 2M paper seeding
2. **Live Arxiv API**: For updates and enrichment
3. **Semantic Scholar**: Author metadata and citations
4. **Ollama**: For embeddings and LLM responses
5. **TUI Interface**: Modern terminal-based user interface

## Performance Targets
```python
# Confirmed performance expectations
PERFORMANCE_TARGETS = {
    'vector_search': {
        'simple_query': '<500ms',
        'complex_query': '<2s',
        'batch_search': '<100ms/paper'
    },
    'database_operations': {
        'paper_insert': '<10ms/batch',
        'bulk_import': '<5min/2M_papers',
        'index_search': '<50ms'
    },
    'graph_operations': {
        'citation_lookup': '<100ms',
        'neighbor_discovery': '<200ms'
    },
    'user_interface': {
        'dashboard_load': '<1s',
        'search_result_display': '<200ms'
    }
}
```

## Success Metrics
```python
# Comprehensive success criteria
SUCCESS_METRICS = {
    'data_quality': {
        'import_success_rate': '>99%',
        'metadata_completeness': '>95%',
        'embedding_quality': '>90%'
    },
    'search_performance': {
        'vector_recall': '>85%',
        'response_relevance': '>80%',
        'user_satisfaction': '>4.0/5'
    },
    'system_performance': {
        'uptime': '>99.5%',
        'query_latency_target': '<2s average',
        'concurrent_users': '>10'
    }
}
```

## Multi-Partition Database Schema
```sql
-- Year + Month partitions for papers
CREATE TABLE papers_2024_01 PARTITION OF papers
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Hash partitions for embeddings
CREATE TABLE paper_embeddings_hash_00 PARTITION OF paper_embeddings
FOR VALUES FROM ('\x00') TO ('\xff');

-- Date partitions for conversations
CREATE TABLE conversations_2024_01 PARTITION OF conversations
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

## Multiple Embedding Strategies
```sql
-- Different embedding types for different use cases
CREATE TABLE paper_embeddings (
    paper_id UUID REFERENCES papers(id),
    embedding_type VARCHAR(20), -- 'title_lg', 'title_sm', 'abstract_lg', 'abstract_sm'
    embedding VECTOR(1536) OR VECTOR(768), -- Dim based on type
    embedding_model VARCHAR(50), -- 'text-embedding-3-large', 'nomic-embed-text'
    performance_score DECIMAL(3,2), -- For model comparison
    created_at TIMESTAMP
);
```

## LangGraph Integration Reference
- LangGraph Documentation: https://langchain-ai.github.io/langgraph/
- State Management: See docs/langgraph/state.md
- Nodes and Edges: See docs/langgraph/nodes_edges.md
- Checkpointing: See docs/langgraph/state.md#checkpointing

This PRD will be iterated on as we build.