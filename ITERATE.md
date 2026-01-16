# Iteration Topics for Arxiv Research Agent

This document lists the key topics to discuss and iterate on before full implementation. Based on PRDs (PRD.md, RAG_PRD.md, CONTEXT_PRD.md) and recent planning, prioritize these for refinement.

## Topics to Iterate On
- **BranchAgent Design**: Specialized agent for dynamic context branching (exploration via LLM, evaluation combining faithfulness/relevance, merging via Context Management). Triggered by query heuristics (e.g., length/entropy). Only agent type for now.
1. **CLI Interface Design (TUI with Textual)**: Design the terminal UI pages (chat, papers, automator, metrics). Discuss layouts, navigation, user interactions (e.g., liking papers), and integration with LangGraph.

2. **TUI Metrics Page**: Design real-time metrics display (e.g., DB stats, query rates) using logs. Ensure it's local and runtime-focused.

3. **Agent Communication & State Sharing**: Define how multiagents (supervisor + subgraphs) share state (e.g., liked embeddings). Cover persistence, concurrency, and inter-session syncing.
   - **Decision**: Keep stateful for context-heavy tasks (e.g., CLI chat, Context Management). Stateless could work for isolated RAG queries but loses history. Use hybrid: Stateful graphs with DB persistence.
   - **Proposal**: Use LangGraph's TypedDict state with shared fields (e.g., liked_embeddings as list of vectors). Supervisor updates global state; subgraphs read/write via nodes. Persistence via MemorySaver for sessions; Chroma/SQLite for long-term (load on startup).
   - **Communication**: Command-based routing (no direct messaging); state mutations trigger updates.
   - **Edge Cases**: Concurrent CLI/automator runs—use locks or queue. Session isolation via user IDs.
   - **Completed**: Discussed stateful vs. stateless; chose stateful with BranchAgent integration.

4. **Prompt Engineering**: Develop structured prompts for RAG (retrieval, grading, rewriting), Context Management (summarization, pruning), and agents (routing, classification). Include fine-tuning via user feedback loops.

5. **Arxiv Interface (Custom arxiv_sdk)**: Confirm the custom module handles rate limiting/retries. Integrate as tool in automator nodes.

6. **User Feedback Loops**: Implement "like" ratings in TUI; collect data for quality classification (authors/categories → importance). (Linked to relevance engine.)

7. **Error Handling & Robustness**: Detail retries, fallbacks, and interrupts across components.

8. **Testing Strategy**: Outline unit/integration tests and evaluation metrics.

9. **Deployment & Scaling**: Local setup; handle DB growth/pruning.

10. **Logging & Monitoring**: JSON logs, metrics collection, basic alerting.

- **Semantic Scholar SDK Integration**: Integrate external SDK for author/paper data (citations, h-index). (See DATA_PRD.md.)

Mark topics as completed once discussed. Update this file during iterations.