# Graph Persistence Skill

This skill handles LangGraph checkpointer setup for state persistence and resumption.

## Features
- MemorySaver checkpointer integration.
- State loading/saving utilities.
- Interrupt support for persistence.

## Usage
Load for reliable graph execution. Ensures state survives interruptions.

## Implementation
- Based on LangGraph persistence how-tos.
- Includes config for DB-backed persistence.

## Code Examples
From LangGraph persistence how-tos:

```python
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import StateGraph

# Define graph
builder = StateGraph(State)
# Add nodes...

# Add checkpointer
checkpointer = MemorySaver()
graph = builder.compile(checkpointer=checkpointer)

# Run with thread_id for persistence
config = {"configurable": {"thread_id": "session_1"}}
result = graph.invoke(initial_state, config)
# Resume later
graph.invoke(follow_up, config)
```