# LangGraph Skill

This skill provides documentation and best practices for building agents with LangGraph, based on up-to-date design principles.

## Loading the Skill

To use this skill, load it in your opencode session as needed for agent development.

## Up-to-Date LangGraph Design Principles

Follow these steps to build robust, stateful agents with LangGraph:

### Step 1: Map Workflow to Discrete Nodes

Identify distinct steps in your process. Each step becomes a node (a function for one specific thing). Sketch connections between nodes.

Node types:
- **LLM Steps**: For understanding, analyzing, generating text, or reasoning.
- **Data Steps**: For retrieving information from external sources.
- **Action Steps**: For performing external actions.
- **User Input Steps**: For human intervention.

### Step 2: Identify What Each Node Needs

For each node, determine required context and outcomes:
- Static context (prompts, guidelines).
- Dynamic context (from state).
- Desired outcome (e.g., classifications, responses).

### Step 3: Design Your State

State is shared memory for all nodes. Store raw data only, not formatted prompts.

What belongs in state:
- Data that persists across steps.
- Avoid derivable data; compute on-demand.

Keep state raw: Format prompts inside nodes when needed.

Example state structure:
```python
from typing import TypedDict

class AgentState(TypedDict):
    raw_data: str
    classification: dict | None
    results: list | None
```

### Step 4: Build Your Nodes

Implement each step as a function taking state and returning updates.

Handle errors appropriately:
- Transient errors (e.g., network): Retry with policy.
- LLM-recoverable errors: Store error and loop back.
- User-fixable errors: Pause with interrupt().
- Unexpected errors: Let them bubble up.

Example node:
```python
def classify_node(state: AgentState) -> Command[Literal["next_node"]]:
    # Do work, handle errors
    return Command(update={"classification": result}, goto="next_node")
```

### Step 5: Wire It Together

Connect nodes in a graph with minimal edges. Nodes handle routing via Command.

Compile with checkpointer for persistence if using interrupts.

Example:
```python
workflow = StateGraph(AgentState)
workflow.add_node("node1", node1)
# Add edges
app = workflow.compile(checkpointer=MemorySaver())
```

### Key Insights

- Break into discrete steps for resilience and observability.
- State stores raw data; nodes format as needed.
- Nodes are functions returning updates and routing decisions.
- Errors are part of the flow: retries, loops, interrupts.
- Human input is first-class; use interrupt() first in nodes.
- Graph structure emerges from node routing.

### Advanced Considerations

- Node granularity: Smaller nodes for more checkpoints and isolation.
- Performance: Async durability for frequent checkpoints without slowdown.

Use these principles for building complex, stateful agents.