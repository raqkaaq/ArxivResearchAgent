# Graph Persistence Skill

This skill handles Orchestral AI checkpointer setup for state persistence and resumption in graph-based agents.

## Features
- MemorySaver checkpointer integration for Orchestral AI graphs.
- State loading/saving utilities for persistent graph execution.
- Interrupt support for human-in-loop interventions.
- DB-backed persistence options for long-term state management.

## Usage
Load for reliable graph execution with Orchestral AI. Ensures state survives interruptions and supports session resumption.

## Implementation
- Based on Orchestral AI persistence patterns for agent graphs.
- Includes config for PostgreSQL-backed and memory-based persistence.

## Code Examples
From Orchestral AI persistence patterns:

```python
from orchestral_ai import Graph, Checkpointers
from orchestral_ai.nodes import AgentNode

# Define graph with checkpointer
checkpointer = Checkpointers.memory()

graph = Graph(
    nodes=[
        AgentNode(name="researcher", ...),
    ],
    checkpointer=checkpointer
)

# Run with thread_id for persistence
config = {"configurable": {"thread_id": "session_1"}}
result = graph.invoke(initial_state, config)

# Resume later
graph.invoke(follow_up, config)
```

## Integration with Project
- Used in supervisor agent for CLI/automator subgraph state persistence.
- Enables BranchAgent to maintain branching context across interruptions.
- Coordinates with PostgreSQL and SQLite for hybrid state storage.