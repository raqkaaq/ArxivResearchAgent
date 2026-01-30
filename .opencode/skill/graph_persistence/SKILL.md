# Graph Persistence Skill

This skill handles LangGraph state/checkpoint persistence for agent execution and resumption.

## Documentation
For detailed architecture and patterns, reference:
- [State Management](../../../../docs/langgraph/state.md)
- [Architecture Overview](../../../../docs/langgraph/architecture.md)

## Features
- State checkpointing for state survival across interruptions.
- Session resumption capabilities.
- Integration with SQLite, PostgreSQL, and Memory for hybrid state storage.
- Time travel support for debugging and exploration.

## Usage
Load for reliable agent execution with LangGraph. Ensures state survives interruptions and supports session resumption.

## Implementation
Based on LangGraph persistence patterns for agents.
Includes config for database-backed persistence.

## Code Examples
From LangGraph persistence patterns:

```python
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.sqlite import SqliteSaver
from typing import TypedDict

class AgentState(TypedDict):
    input: str
    result: str | None

# Create checkpointer
sqlite = SqliteSaver.from_conn_string("checkpoints.db")

# Create graph
graph = StateGraph(AgentState)
graph.add_node("process", lambda s: {"result": f"processed: {s['input']}"})
graph.set_entry_point("process")
graph.add_edge("process", END)

# Compile with checkpointer
app = graph.compile(checkpointer=sqlite)

# Run with checkpointing
config = {"configurable": {"thread_id": "session_123"}}
result = app.invoke({"input": "hello"}, config=config)

# Resume with same config (state persists)
result = app.invoke({"input": "world"}, config=config)

# Time travel: List checkpoints
for checkpoint in app.checkpointer.list(config):
    print(f"ID: {checkpoint['id']}, Created: {checkpoint['metadata']['created_at']}")

# Replay from checkpoint
replay_config = {
    "configurable": {
        "thread_id": "session_123",
        "checkpoint_id": "checkpoint_abc"
    }
}
for event in app.stream(None, config=replay_config):
    print(event)
```

## Integration with Project
- Used in supervisor agent for CLI/automator subgraph state persistence.
- Enables BranchAgent to maintain branching context across interruptions.
- Coordinates with PostgreSQL and SQLite for hybrid state storage.