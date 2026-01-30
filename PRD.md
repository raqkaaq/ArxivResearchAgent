# Product Requirements Document (PRD): Arxiv Research Agent

## Overview
The Arxiv Research Agent is a dynamic, multiagent AI system built with LangGraph for researching, downloading, and compiling important details from Arxiv publications. It consists of two main components: a user-interactive CLI chatbot for querying and managing research, and a user-triggered automator for proactive ingestion and classification of recent papers. The system uses Ollama (primary) or Gemini (configurable fallback) for LLM tasks, PostgreSQL + pgvector for embedding-based RAG retrieval, Neo4j for graph-based relationship analysis, and local file storage for papers.

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
  - Store high-importance papers (metadata in PostgreSQL, embeddings in PostgreSQL, relationships in Neo4j, downloads in papers/ directory).
  - Prune old/unimportant data to manage storage.
- **Shared Infrastructure**:
  - Vector & Metadata DB (PostgreSQL + pgvector) for vector search, similarity matching, and structured paper details.
  - Graph DB (Neo4j) for citation networks, author relationships, and knowledge graph operations.
  - Paper Storage (papers/ directory) for selective PDF/source downloads.
  - Logging (logs/ directory) with structured JSON logs for actions, errors, and metrics.
  - Context Management: Adaptive compression for long conversations with dynamic token thresholds based on LLM. (See CONTEXT_PRD.md for detailed system design, including architecture diagrams and inspirations from modern papers.)
  - LLM Config: Ollama for local inference; Gemini for API-based fallback/scalability.
- **Intelligence & Dynamics**:
  - Similarity-based filtering: Use cosine similarity on embeddings (PostgreSQL pgvector) and graph relationships (Neo4j) to find papers "similar to liked ones."
  - Adaptive Classification: LLM evaluates papers for importance, considering user context.
  - Selective Downloads: Only download top-scoring papers to avoid storage bloat.
  - Error Handling: Retries for API failures, interrupts for config issues, detailed logging.

## Architecture
- **Tech Stack**:
  - LangGraph: For multiagent stateful graphs (supervisor + subgraphs).
  - Arxiv SDK (arxiv.py): For searching, fetching metadata.
  - Semantic Scholar SDK (external): For citations, h-index, paper counts, and downloading.
  - PostgreSQL + pgvector: Vector database and structured metadata for embeddings and paper details (in db/postgres/, shared with RAG and Context Management).
  - Neo4j: Graph database for citation networks, author relationships, and knowledge graph operations (in db/neo4j/, shared with RAG and Agent coordination).
  - LangChain Ollama/Gemini: For LLM and embeddings.
  - Python: Core language (version dictated by conda env). (See RAG_PRD.md and CONTEXT_PRD.md for RAG and Context-specific components.)
- **Multiagent Structure**:
  - **Supervisor Agent**: Routes to CLI or Automator subgraphs based on input.
  - **CLI Subgraph**: Handles user interactions (nodes: input, RAG, research, response, like).
  - **Automator Subgraph**: Handles background ingestion (nodes: pull, embed, similarity, classify, store, clean).
- **State Management**:
  - SharedState: PostgreSQL/Neo4j clients, liked embeddings, cross-database references.
  - CLIState: User query, retrieved papers, hybrid response.
  - AutomatorState: Recent papers, classified papers, relationship graphs.
- **Data Flow**:
  - CLI: Query → Embed → Hybrid Search (PostgreSQL vectors + Neo4j relationships) → Respond.
  - Automator: Pull Arxiv → Store PostgreSQL + Build Neo4j → Classify → Hybrid Storage.
- **Deployment**: Local Python scripts; CLI via command-line (e.g., `python main.py --chat` or `python main.py --automate`).

## Requirements
- **Functional**:
  - Search Arxiv with queries/ID lists.
  - Fetch metadata (title, authors, summary, categories, links) or enriched data from Semantic Scholar (citations, h-index, paper counts).
  - Download PDFs/sources selectively.
  - Embed text for similarity search.
  - Classify papers with LLM scores.
  - Store and retrieve via hybrid database (PostgreSQL + Neo4j) with cross-system consistency.
  - Log all actions with timestamps/levels.
  - Execute cross-database transactions with rollback capabilities.
- **Non-Functional**:
  - Performance: Handle 100+ papers per run; hybrid RAG retrieval <3s; cross-database query latency <1s.
  - Reliability: Retry on failures; cross-database consistency validation; log errors.
  - Security: No secrets in code; use env vars for API keys; secure cross-database connections.
  - Usability: Simple CLI commands; clear responses; transparent hybrid query routing.
  - Scalability: Prune PostgreSQL and Neo4j datasets; configurable limits (e.g., max papers=2000).
  - Data Consistency: Atomic operations across both databases with conflict resolution.
- **Dependencies**:
  - Python 3.9+.
  - Packages: langgraph, langchain-ollama, langchain-google-genai, langchain-postgres, langchain-neo4j, psycopg2-binary, neo4j-driver, pgvector, arxiv, requests, tenacity, diskcache, redis (for cross-database caching).
  - External Services: PostgreSQL, Neo4j, Docker, Ollama.
  - Environment Configuration: Hybrid system requires coordinated config management.
  - Development Tools: Docker Compose, connection poolers, health monitoring.
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

## Cross-Database Architecture
- **Transaction Management**: Atomic operations across PostgreSQL and Neo4j with rollback capabilities. Event-driven synchronization for eventual consistency patterns.
- **Query Federation**: Intelligent routing and result fusion across PostgreSQL vectors and Neo4j graphs with deduplication and advanced ranking.
- **Data Synchronization**: Background services maintaining consistency with conflict resolution and performance optimization.
- **Error Handling**: Cascading rollback procedures and partial failure recovery across both database systems.

## Implementation Framework
- **Database Coordination**: Connection pooling, failover procedures, and circuit breaker patterns for hybrid reliability.
- **Migration Strategy**: Coordinated backup/restore and performance validation during transition periods.
- **Performance Monitoring**: Cross-database metrics, health checking, and automated scaling recommendations.

## Timeline & Milestones
- Week 1: Finalize PRD (this doc) and cross-database architecture details.
- Week 2: Implement core agents and hybrid DB setup with coordination layer.
- Week 3: Integrate LLMs and hybrid RAG with query federation.
- Week 4: Testing cross-database consistency and performance optimization.
- Ongoing: Iterate based on user analytics, TUI interaction data, and progressive system monitoring.

This PRD will be iterated on as we build.