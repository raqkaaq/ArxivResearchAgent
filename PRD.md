# Product Requirements Document (PRD): Arxiv Research Agent

## Overview
The Arxiv Research Agent is a dynamic, multiagent AI system built with LangGraph for researching, downloading, and compiling important details from Arxiv publications. It consists of two main components: a user-interactive CLI chatbot for querying and managing research, and a user-triggered automator for proactive ingestion and classification of recent papers. The system uses Ollama (primary) or Gemini (configurable fallback) for LLM tasks, Chroma for embedding-based RAG retrieval, SQLite for metadata storage, and local file storage for papers.

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
- **User-Triggered Automator**:
  - Pull recent Arxiv papers (e.g., last 24-48 hours).
  - Embed papers and compare to user-liked baselines for similarity.
  - Classify importance using LLM (1-10 score based on novelty, impact, relevance).
  - Store high-importance papers (metadata in SQLite, embeddings in Chroma, downloads in papers/ directory).
  - Prune old/unimportant data to manage storage.
- **Shared Infrastructure**:
  - Embedding DB (Chroma) for vector search and similarity matching.
  - Metadata DB (SQLite) for structured paper details.
  - Paper Storage (papers/ directory) for selective PDF/source downloads.
  - Logging (logs/ directory) with structured JSON logs for actions, errors, and metrics.
  - Context Management: Adaptive compression for long conversations. (See CONTEXT_PRD.md for detailed system design, including architecture diagrams and inspirations from modern papers.)
  - LLM Config: Ollama for local inference; Gemini for API-based fallback/scalability.
- **Intelligence & Dynamics**:
  - Similarity-based filtering: Use cosine similarity on embeddings to find papers "similar to liked ones."
  - Adaptive Classification: LLM evaluates papers for importance, considering user context.
  - Selective Downloads: Only download top-scoring papers to avoid storage bloat.
  - Error Handling: Retries for API failures, interrupts for config issues, detailed logging.

## Architecture
- **Tech Stack**:
  - LangGraph: For multiagent stateful graphs (supervisor + subgraphs).
  - Arxiv SDK (arxiv.py): For searching, fetching metadata, downloading.
  - ChromaDB: Vector database for embeddings (shared with RAG and Context Management).
  - NetworkX: For knowledge graph modeling in RAG.
  - SQLite: Relational DB for metadata and conversation logs (shared with Context Management).
  - LangChain Ollama/Gemini: For LLM and embeddings.
  - Python: Core language. (See RAG_PRD.md and CONTEXT_PRD.md for RAG and Context-specific components.)
- **Multiagent Structure**:
  - **Supervisor Agent**: Routes to CLI or Automator subgraphs based on input.
  - **CLI Subgraph**: Handles user interactions (nodes: input, RAG, research, response, like).
  - **Automator Subgraph**: Handles background ingestion (nodes: pull, embed, similarity, classify, store, clean).
- **State Management**:
  - SharedState: Chroma/SQLite clients, liked embeddings, logs.
  - CLIState: User query, retrieved papers, response.
  - AutomatorState: Recent papers, classified papers, downloaded paths.
- **Data Flow**:
  - CLI: Query → Embed → Search Chroma/SQLite → Respond.
  - Automator: Pull Arxiv → Embed → Compare Similarity → Classify → Store.
- **Deployment**: Local Python scripts; CLI via command-line (e.g., `python main.py --chat` or `python main.py --automate`).

## Requirements
- **Functional**:
  - Search Arxiv with queries/ID lists.
  - Fetch metadata (title, authors, summary, categories, links).
  - Download PDFs/sources selectively.
  - Embed text for similarity search.
  - Classify papers with LLM scores.
  - Store and retrieve via DBs.
  - Log all actions with timestamps/levels.
- **Non-Functional**:
  - Performance: Handle 100+ papers per run; RAG retrieval <5s.
  - Reliability: Retry on failures; log errors.
  - Security: No secrets in code; use env vars for API keys.
  - Usability: Simple CLI commands; clear responses.
  - Scalability: Prune DBs; configurable limits (e.g., max papers=1000).
- **Dependencies**:
  - Python 3.9+.
  - Packages: langgraph, langchain-ollama, langchain-google-genai, chromadb, sqlite3, arxiv.
- **Assumptions**:
  - User has Ollama installed locally.
  - Server may not be always online (hence user-triggered automator).
  - Arxiv API rate limits respected (3s delay).
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
- Week 1: Finalize PRD (this doc).
- Week 2: Implement core agents and DB setup.
- Week 3: Integrate LLMs and RAG.
- Week 4: Testing and logging.
- Ongoing: Iterate based on user feedback.

This PRD will be iterated on as we build.