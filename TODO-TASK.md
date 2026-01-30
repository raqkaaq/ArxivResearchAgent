# TODO: Arxiv Research Agent Implementation

This TODO outlines the iterative implementation of the Arxiv Research Agent system, based on the PRDs. Tasks are organized into phases for manageable progress. Check off completed items with [x]. Focus on testing and integration at each step.

## Phase 1: Setup & Infrastructure
- [ ] Create project directory structure (agents/, rag/, context/, db/)
- [ ] Initialize directories (db/postgres, db/neo4j, logs/, papers/)
- [ ] Set up conda environment and install latest packages
- [ ] Configure .env file for API keys (OLLAMA_BASE_URL, GEMINI_API_KEY, POSTGRES_URL, NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD)
- [ ] Test Ollama connection and model loading
- [ ] Initialize PostgreSQL and Neo4j DBs
- [ ] Unit test: Verify DB connections and basic operations

## Phase 2: Core Data & Retrieval
- [ ] Integrate Arxiv SDK for search and metadata fetching
- [ ] Integrate external Semantic Scholar SDK for citations/h-index/paper counts
- [ ] Implement hybrid data collection (Arxiv or Semantic Scholar for quality features)
- [ ] Set up PostgreSQL with pgvector for embedding storage (Ollama embeddings)
- [ ] Basic embedding and retrieval test (mock data)
- [ ] Unit test: Data fetching and embedding accuracy

## Phase 3: RAG System
- [ ] Load and use rag_orchestrator skill for retrieval nodes
- [ ] Implement vector-based retrieval in PostgreSQL with pgvector
- [ ] Build Neo4j knowledge graph (nodes: papers/authors, edges: citations)
- [ ] Add PageRank for importance ranking in graph
- [ ] Add centrality and shortest path algorithms
- [ ] Integrate HyDE for hypothetical embeddings
- [ ] Implement agentic nodes (retrieve, grade, rewrite)
- [ ] Hybrid retrieval test (vector + graph)
- [ ] Unit test: RAG retrieval relevance

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
- [ ] Unit test: Routing and subgraph execution
- [ ] Integration test: Basic CLI flow

## Phase 5: Advanced Features
- [ ] Load context_manager skill for compression
- [ ] Implement Context Management with dynamic thresholds using context_manager
- [ ] Add compression endpoints (compress_chain, merge_into_chain)
- [ ] Implement BranchAgent (triggers, exploration, evaluation, merging) using branch_agent skill
- [ ] Integrate BranchAgent into supervisor
- [ ] Full multiagent test (CLI + Automator + BranchAgent)
- [ ] Unit test: Context handling and branching

## Phase 6: UI & Polish
- [ ] Build TUI with Textual (chat, papers, automator, metrics pages)
- [ ] Implement real-time metrics display
- [ ] Add comprehensive logging and error handling
- [ ] End-to-end integration test
- [ ] User acceptance test: Full workflow

## Testing & Validation
- [ ] Unit tests for all components
- [ ] Integration tests for phases
- [ ] Performance tests (retrieval latency, DB growth)
- [ ] Evaluation: RAG relevance metrics (BLEU, recall), classification accuracy
- [ ] Validation: User feedback loops and quality classification data collection

## Dependencies & Notes
- Requires: Conda env, Ollama, PostgreSQL, Neo4j, external SDKs.
- Missing: Deployment scripts, user docs, scalability (DB pruning).
- Iterate: After each phase, review and adjust PRDs.
- Prioritize: Core RAG and agents first, advanced features later.