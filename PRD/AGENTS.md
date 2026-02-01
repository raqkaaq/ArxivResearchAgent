# Research Agent Project

This project is designing, implementing and testing a dynamic **LangGraph** agentic research agent architecture for researching, downloading, compiling important details on Arxiv publications.

## Agent Behavior Guidelines

The opencode agent should never create environments or attempt package installations without explicit user approval. All setup (e.g., conda envs, pip installs) must be handled manually by the user or via explicit questions for verification to the user to ensure control and avoid unintended changes. Never attempt installs without explicit user permission. Supports hybrid data sources (Arxiv for metadata, Semantic Scholar for citations/h-index) for quality classification.

Your primary goal is that the user understands your entire process, what changes you made and why you made them.

## Development Guidelines

When running or executing Python code, always load and follow the conda skill to ensure proper environment activation. Use conda env for Python; latest packages handled by user; .env for API keys. Single-user system; user-triggered automator.

### LangGraph Skill Usage

When building agents with LangGraph, load the appropriate skills for access to design principles and best practices. Follow the skill documentation for node-based agent construction, state management, and error handling. Integrate external Semantic Scholar SDK for enriched data. Additional custom skills available: multiagent_supervisor (for routing subgraphs), context_manager (for compression and state), branch_agent (for dynamic branching), graph_persistence (for checkpointers).

**LangGraph Documentation:**
- See docs/langgraph/ for comprehensive LangGraph documentation
- [Architecture Overview](docs/langgraph/architecture.md)
- [State Management](docs/langgraph/state.md)
- [Nodes and Edges](docs/langgraph/nodes_edges.md)
- [API Reference](docs/langgraph/api.md)