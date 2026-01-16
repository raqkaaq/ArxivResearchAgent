# TODO: Arxiv Research Agent Implementation

This TODO outlines the iterative implementation of the Arxiv Research Agent system, based on the PRDs. Tasks are organized into phases for manageable progress. Check off completed items with [x]. Focus on testing and integration at each step.

## Phase 1: Setup & Infrastructure
- [ ] Create project directory structure (agents/, rag/, context/, db/)
- [ ] Initialize directories (db/chroma, db/sqlite, logs/, papers/)
- [ ] Set up conda environment and install latest packages
- [ ] Configure .env file for API keys (OLLAMA_BASE_URL, GEMINI_API_KEY)
- [ ] Test Ollama connection and model loading
- [ ] Initialize Chroma and SQLite DBs
- [ ] Unit test: Verify DB connections and basic operations

## Phase 2: Core Data & Retrieval
- [ ] Integrate Arxiv SDK for search and metadata fetching
- [ ] Integrate external Semantic Scholar SDK for citations/h-index/paper counts
- [ ] Implement hybrid data collection (Arxiv or Semantic Scholar for quality features)
- [ ] Set up Chroma for embedding storage (Ollama embeddings)
- [ ] Basic embedding and retrieval test (mock data)
- [ ] Unit test: Data fetching and embedding accuracy

## Phase 3: RAG System
- [ ] Implement vector-based retrieval in Chroma
- [ ] Build NetworkX knowledge graph (nodes: papers/authors, edges: citations)
- [ ] Add PageRank for importance ranking in graph
- [ ] Add centrality and shortest path algorithms
- [ ] Integrate HyDE for hypothetical embeddings
- [ ] Implement agentic nodes (retrieve, grade, rewrite)
- [ ] Hybrid retrieval test (vector + graph)
- [ ] Unit test: RAG retrieval relevance

## Phase 4: Agent Layer
- [ ] Implement supervisor agent for routing (CLI vs. Automator)
- [ ] Build CLI subgraph (input, RAG, response nodes)
- [ ] Add user feedback collection (likes in SQLite)
- [ ] Build Automator subgraph (pull, embed, similarity, classify nodes)
- [ ] Integrate Arxiv/Semantic Scholar for ingestion
- [ ] Unit test: Routing and subgraph execution
- [ ] Integration test: Basic CLI flow

## Phase 5: Advanced Features
- [ ] Implement Context Management with dynamic thresholds
- [ ] Add compression endpoints (compress_chain, merge_into_chain)
- [ ] Implement BranchAgent (triggers, exploration, evaluation, merging)
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
- [ ] Validation: User feedback loops and quality classification data collection

## Dependencies & Notes
- Requires: Conda env, Ollama, external SDKs.
- Iterate: After each phase, review and adjust PRDs.
- Prioritize: Core RAG and agents first, advanced features later.