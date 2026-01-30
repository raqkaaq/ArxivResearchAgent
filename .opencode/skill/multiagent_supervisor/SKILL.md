# Multiagent Supervisor Skill

This skill provides a reusable Orchestral AI-based supervisor agent for orchestrating multiple subgraphs (e.g., CLI and Automator). It handles routing based on input, shared state management, and Command-based transitions between subgraphs.

## Features
- Supervisor node with conditional routing (e.g., to CLI or Automator subgraphs).
- Shared state initialization and updates across subgraphs.
- Integration with checkpointer for persistence.
- Hybrid query routing for PostgreSQL + Neo4j operations.

## Usage
Load this skill in opencode sessions for multiagent Orchestral AI setups. Use in agent construction for routing logic between CLI chatbot and automator subgraphs.

## Implementation
- Based on AGENT_PRD.md supervisor design for Orchestral AI.
- Includes example code for TypedDict state and Command routing.
- Coordinates with BranchAgent for complex query handling.

## Code Examples
From Supervisor Agent design:

```python
from orchestral_ai import Graph, AgentNode, Command
from typing import TypedDict, List, Literal

# Define shared state
class SharedState(TypedDict):
    input: str
    liked_embeddings: List[List[float]]
    postgres_client: object
    neo4j_connection: object
    sqlite_conn: object

# Supervisor node
def supervisor(state: SharedState) -> Command[Literal["cli_subgraph", "automator_subgraph"]]:
    input_text = state["input"].lower()
    
    if "chat" in input_text or "research" in input_text:
        return Command(goto="cli_subgraph")
    elif "automate" in input_text or "ingest" in input_text:
        return Command(goto="automator_subgraph")
    else:
        # Default to CLI for natural language queries
        return Command(goto="cli_subgraph")

# Build graph with supervisor
graph = Graph(
    nodes=[
        AgentNode(name="supervisor", supervisor),
        AgentNode(name="cli_subgraph", ...),
        AgentNode(name="automator_subgraph", ...),
    ]
)
```

## Subgraph Routing
- **CLI Subgraph**: Handles user interactions (input validation, hybrid RAG retrieval, response generation, like updates)
- **Automator Subgraph**: Handles background ingestion (pull Arxiv papers, embed, similarity check, classify, store, clean)