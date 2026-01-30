# Product Requirements Document (PRD): Arxiv Research Agent

## Overview
The Arxiv Research Agent is a dynamic, multiagent AI system built with LangGraph for researching, downloading, and compiling important details from Arxiv publications. It consists of two main components: a user-interactive CLI chatbot for querying and managing research, and a user-triggered automator for proactive ingestion and classification of recent papers. The system uses Ollama (primary) or Gemini (configurable fallback) for LLM tasks, Chroma for embedding-based RAG retrieval, NetworkX for in-memory graph-based relationship analysis, SQLite for user feedback storage, and local file storage for papers.

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
  - **TUI Interface**: Modern terminal-based user interface with progressive result display, research analytics dashboard, and real-time system metrics.
  - **Progressive Analytics Dashboard**: Real-time display of ingestion progress, citation network statistics, author collaboration metrics, and system health monitoring.
- **User-Triggered Automator**:
  - Pull recent Arxiv papers (e.g., last 24-48 hours).
  - Embed papers and compare to user-liked baselines for similarity.
  - Classify importance using LLM (1-10 score based on novelty, impact, relevance), with data from Semantic Scholar (citations/h-index) or Arxiv (metadata) for training.
  - Store high-importance papers (embeddings in Chroma, metadata in SQLite, graph relationships in NetworkX, downloads in papers/ directory).
  - Prune old/unimportant data to manage storage.
- **Shared Infrastructure**:
  - Vector DB (Chroma) for vector search and similarity matching.
  - Graph DB (NetworkX) for in-memory citation networks and knowledge graph operations.
  - SQLite for user feedback ("likes") and structured metadata.
  - Paper Storage (papers/ directory) for selective PDF/source downloads.
  - Logging (logs/ directory) with structured JSON logs for actions, errors, and metrics.
  - Context Management: Adaptive compression for long conversations with dynamic token thresholds based on LLM. (See CONTEXT_PRD.md for detailed system design, including architecture diagrams and inspirations from modern papers.)
  - LLM Config: Ollama for local inference; Gemini for API-based fallback/scalability.
- **Intelligence & Dynamics**:
  - Similarity-based filtering: Use cosine similarity on embeddings (Chroma) and graph relationships (NetworkX) to find papers "similar to liked ones."
  - Adaptive Classification: LLM evaluates papers for importance, considering user context.
  - Selective Downloads: Only download top-scoring papers to avoid storage bloat.
  - Error Handling: Retries for API failures, interrupts for config issues, detailed logging.

## Architecture
- **Tech Stack**:
  - LangGraph: For multiagent stateful graphs (supervisor + subgraphs).
  - Arxiv SDK (arxiv.py): For searching, fetching metadata.
  - Semantic Scholar SDK (external): For citations, h-index, paper counts, and downloading.
  - Chroma: Vector database for embeddings and semantic similarity (in db/chroma/, shared with RAG).
  - NetworkX: In-memory graph library for citation networks and knowledge graph operations.
  - SQLite: User feedback storage for "likes" and preferences (in db/sqlite/).
  - LangChain Ollama/Gemini: For LLM and embeddings.
  - Python: Core language (version dictated by conda env). (See RAG_PRD.md and CONTEXT_PRD.md for RAG and Context-specific components.)
- **Multiagent Structure**:
  - **Supervisor Agent**: Routes to CLI or Automator subgraphs based on input.
  - **CLI Subgraph**: Handles user interactions (nodes: input, RAG, research, response, like).
  - **Automator Subgraph**: Handles background ingestion (nodes: pull, embed, similarity, classify, store, clean).
- **State Management**:
  - SharedState: Chroma client, SQLite connection, liked embeddings, NetworkX graph.
  - CLIState: User query, retrieved papers, hybrid response.
  - AutomatorState: Recent papers, classified papers, relationship graphs.
- **Data Flow**:
  - CLI: Query → Embed → Hybrid Search (Chroma vectors + NetworkX graph) → Respond.
  - Automator: Pull Arxiv → Store Chroma + Build NetworkX graph → Classify → Storage.
- **Deployment**: Local Python scripts; CLI via command-line (e.g., `python main.py --chat` or `python main.py --automate`).

## Requirements
- **Functional**:
  - Search Arxiv with queries/ID lists.
  - Fetch metadata (title, authors, summary, categories, links) or enriched data from Semantic Scholar (citations, h-index, paper counts).
  - Download PDFs/sources selectively.
  - Embed text for similarity search.
  - Classify papers with LLM scores.
  - Store and retrieve via hybrid storage (Chroma + NetworkX + SQLite) with in-memory graph consistency.
  - Log all actions with timestamps/levels.
  - User feedback via SQLite for "likes" to personalize recommendations.
- **Non-Functional**:
  - Performance: Handle 100+ papers per run; hybrid RAG retrieval <3s; in-memory graph query <1s.
  - Reliability: Retry on failures; graph consistency validation; log errors.
  - Security: No secrets in code; use env vars for API keys.
  - Usability: Simple CLI commands; clear responses; transparent hybrid query routing.
  - Scalability: Prune Chroma collections and SQLite data; configurable limits (e.g., max papers=2000).
- **Dependencies**:
  - Python 3.9+.
  - Packages: langgraph, langchain-ollama, langchain-google-genai, chromadb, networkx, sqlite3, arxiv, requests, tenacity, diskcache.
  - External Services: Ollama, Docker (optional).
  - Environment Configuration: .env for API keys (OLLAMA_BASE_URL, GEMINI_API_KEY).
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

This PRD will be iterated on as we build.