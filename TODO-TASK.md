# TODO: Arxiv Research Agent Implementation

This TODO outlines the iterative implementation of the Arxiv Research Agent system, based on the PRDs. Tasks are organized into phases for manageable progress. Check off completed items with [x]. Focus on testing and integration at each step.

## Phase 1: Setup & Infrastructure
- [ ] Create project directory structure (agents/, rag/, context/, db/, tui/, embeddings/, data_ingestion/)
- [ ] Initialize directories (db/postgres, db/neo4j, logs/, papers/, data_ingestion/)
- [ ] Set up conda environment and install latest packages
- [ ] Configure .env file for API keys (OLLAMA_BASE_URL, GEMINI_API_KEY, POSTGRES_URL, NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD)
- [ ] Test Ollama connection and model loading
- [ ] Initialize PostgreSQL and Neo4j DBs
- [ ] Set up multi-partition schema for papers (year-month), embeddings (hash), conversations (date)
- [ ] Unit test: Verify DB connections and basic operations

## Phase 2: Core Data & Retrieval
- [ ] Integrate Arxiv SDK for search and metadata fetching
- [ ] Integrate external Semantic Scholar SDK for citations/h-index/paper counts
- [ ] Implement HuggingFace dataset loader for initial 2M paper seeding
- [ ] Implement paper processor with data cleaning and formatting
- [ ] Implement batch importer with partitioned bulk inserts
- [ ] Implement hybrid data collection (Arxiv or Semantic Scholar for quality features)
- [ ] Set up PostgreSQL with pgvector for embedding storage (Ollama embeddings)
- [ ] Implement multiple embedding strategies (title_lg, title_sm, abstract_lg, abstract_sm)
- [ ] Basic embedding and retrieval test (mock data)
- [ ] Implement rate limiting (1000 requests/day for Semantic Scholar) and caching (diskcache)
- [ ] Unit test: Data fetching and embedding accuracy
- [ ] Performance target: <5min for 2M papers bulk import

## Phase 3: RAG System
- [ ] Load and use rag_orchestrator skill for retrieval nodes
- [ ] Implement vector-based retrieval in PostgreSQL with pgvector
- [ ] Build Neo4j knowledge graph (nodes: papers/authors, edges: citations)
- [ ] Add PageRank for importance ranking in graph
- [ ] Add centrality and shortest path algorithms
- [ ] Integrate HyDE for hypothetical embeddings
- [ ] Implement agentic nodes (retrieve, grade, rewrite)
- [ ] Build hybrid retrieval (vector + graph) with fusion and ranking
- [ ] Implement pre-agent mode (standalone chain: Retrieve → Generate)
- [ ] Implement agent tool mode (Orchestral AI graph with conditional edges)
- [ ] Hybrid retrieval test (vector + graph)
- [ ] Unit test: RAG retrieval relevance
- [ ] Performance target: Hybrid RAG retrieval <3s, Neo4j graph query <1s

## Phase 4: Agent Layer
- [ ] Load multiagent_supervisor, branch_agent, graph_persistence skills
- [ ] Implement supervisor agent for routing (CLI vs. Automator) using multiagent_supervisor
- [ ] Add Orchestral AI checkpointer for persistence using graph_persistence
- [ ] Implement interrupts for human-in-loop (e.g., confirm branches)
- [ ] Enable streaming for real-time responses in nodes
- [ ] Integrate tools for external APIs (Arxiv/Semantic Scholar as Orchestral AI tools)
- [ ] Build CLI subgraph (input, RAG, response nodes)
- [ ] Add user feedback collection (likes in SQLite)
- [ ] Build Automator subgraph (pull, embed, similarity, classify nodes) with BranchAgent
- [ ] Integrate Arxiv/Semantic Scholar for ingestion
- [ ] Implement BranchAgent (triggers, exploration, evaluation, merging) using branch_agent skill
- [ ] Integrate BranchAgent into supervisor
- [ ] Unit test: Routing and subgraph execution
- [ ] Integration test: Basic CLI flow

## Phase 5: Context Management
- [ ] Load context_manager skill for compression
- [ ] Implement SQLite schema for conversations (sessions/messages tables)
- [ ] Implement PostgreSQL schema for compressed contexts with partitions
- [ ] Implement Context Manager with dynamic thresholds based on current LLM
- [ ] Add compression endpoints (compress_chain, merge_into_chain)
- [ ] Implement semantic summarization (UltraGist-style)
- [ ] Implement selective pruning (ACON-style ranking)
- [ ] Implement KV cache compression (KVzip-style)
- [ ] Implement hierarchical fitting (short-term in-window, long-term in SQLite)
- [ ] Unit test: Context handling and compression
- [ ] Performance target: Compression preserves 80% relevance, retrieval <1s

## Phase 6: TUI Interface
- [ ] Build TUI with Textual
- [ ] Implement Chat Page (interactive research queries, progressive display, paper details)
- [ ] Implement Papers Page (browse, search, manage liked papers)
- [ ] Implement Automator Page (real-time ingestion progress, classification status, network visualization)
- [ ] Implement Metrics Page (DB stats, query rates, storage usage, system health)
- [ ] Add keyboard navigation and async updates
- [ ] Integrate Research Explorer for RAG results display
- [ ] Integrate Network Visualizer for citation networks
- [ ] End-to-end integration test
- [ ] Performance target: Dashboard load <1s, search result display <200ms

## Phase 7: Advanced Features
- [ ] Implement data fusion for multiple data sources
- [ ] Implement update coordinator for conflict resolution
- [ ] Implement live ingestion agent for background paper processing
- [ ] Implement enrichment agent for author and citation analytics
- [ ] Implement trend analyzer for topic evolution tracking
- [ ] Implement breakthrough detector for impact paper identification
- [ ] Implement collaboration analyzer for research network analysis
- [ ] Full multiagent test (CLI + Automator + BranchAgent)
- [ ] User acceptance test: Full workflow

## Testing & Validation
- [ ] Unit tests for all components
- [ ] Integration tests for phases
- [ ] Performance tests (retrieval latency, DB growth)
- [ ] Evaluation: RAG relevance metrics (BLEU, recall), classification accuracy
- [ ] Validation: User feedback loops and quality classification data collection
- [ ] Success metrics: import_success_rate >99%, vector_recall >85%, response_relevance >80%

## Dependencies & Notes
- Requires: Conda env, Ollama, PostgreSQL, Neo4j, external SDKs.
- Missing: Deployment scripts, user docs, scalability (DB pruning).
- Iterate: After each phase, review and adjust PRDs.
- Prioritize: Core RAG and agents first, advanced features later.

## Performance Targets
- Vector search: simple_query <500ms, complex_query <2s, batch_search <100ms/paper
- Database operations: paper_insert <10ms/batch, bulk_import <5min/2M_papers, index_search <50ms
- System: query_latency_target <2s average, uptime >99.5%
