# Multiagent Supervisor Skill

This skill provides a reusable LangGraph-based supervisor agent for orchestrating multiple subgraphs (e.g., CLI and Automator). It handles routing based on input, shared state management, and conditional transitions between subgraphs.

## Documentation
For detailed architecture and patterns, reference:
- [Architecture Overview](../../../../docs/langgraph/architecture.md)
- [API Reference](../../../../docs/langgraph/api.md)
- [Examples](../../../../docs/langgraph/examples.md)
- [State Management](../../../../docs/langgraph/state.md)

## Features
- Supervisor node with conditional routing (e.g., to CLI or Automator subgraphs).
- Shared state initialization and updates across subgraphs.
- Integration with checkpointer for persistence.
- Hybrid query routing for PostgreSQL + Neo4j operations.

## Usage
Load this skill in opencode sessions for multiagent LangGraph setups. Use in agent construction for routing logic between CLI chatbot and automator subgraphs.

## Implementation
Based on AGENT_PRD.md supervisor design for LangGraph.
Includes example code for TypedDict state and conditional routing.
Coordinates with BranchAgent for complex query handling.

## Code Examples
From Supervisor Agent design:

```python
from typing import TypedDict, List, Literal
from langgraph.graph import StateGraph, END, START
from langchain_openai import ChatOpenAI

# Define shared state
class SharedState(TypedDict):
    input: str
    liked_embeddings: List[List[float]]
    postgres_client: object
    neo4j_connection: object
    sqlite_conn: object

# Supervisor node with conditional routing
def supervisor(state: SharedState):
    input_text = state["input"].lower()
    
    if "chat" in input_text or "research" in input_text:
        return {"next": "cli_subgraph"}
    elif "automate" in input_text or "ingest" in input_text:
        return {"next": "automator_subgraph"}
    else:
        # Default to CLI for natural language queries
        return {"next": "cli_subgraph"}

# Build supervisor graph
graph = StateGraph(SharedState)
graph.add_node("supervisor", supervisor)
graph.set_entry_point("supervisor")
graph.add_conditional_edges(
    "supervisor",
    lambda s: s.get("next", "end"),
    {
        "cli_subgraph": "cli_entry",
        "automator_subgraph": "automator_entry",
        "END": END
    }
)
```

## Subgraph Routing
- **CLI Subgraph**: Handles user interactions (input validation, hybrid RAG retrieval, response generation, like updates)
- **Automator Subgraph**: Handles background ingestion (pull Arxiv papers, embed, similarity check, classify, store, clean)