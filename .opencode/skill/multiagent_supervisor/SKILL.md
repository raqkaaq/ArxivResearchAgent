# Multiagent Supervisor Skill

This skill provides a reusable LangGraph-based supervisor agent for orchestrating multiple subgraphs (e.g., CLI and Automator). It handles routing based on input, shared state management, and Command-based transitions.

## Features
- Supervisor node with conditional routing (e.g., to CLI or Automator subgraphs).
- Shared state initialization and updates.
- Integration with checkpointer for persistence.

## Usage
Load this skill in opencode sessions for multiagent setups. Use in agent construction for routing logic.

## Implementation
- Based on LangGraph tutorials for agent supervisors.
- Includes example code for TypedDict state and Command routing.

## Code Examples
From LangGraph multi-agent tutorials:

```python
from langgraph.graph import StateGraph, START, END
from langgraph.types import Command

# Define shared state
class SharedState(TypedDict):
    input: str
    liked_embeddings: List[List[float]]

# Supervisor node
def supervisor(state: SharedState) -> Command[Literal["cli", "automator"]]:
    if "chat" in state["input"]:
        return Command(goto="cli")
    return Command(goto="automator")

# Build graph
builder = StateGraph(SharedState)
builder.add_node("supervisor", supervisor)
builder.add_edge(START, "supervisor")
# Add subgraphs...
graph = builder.compile()
```