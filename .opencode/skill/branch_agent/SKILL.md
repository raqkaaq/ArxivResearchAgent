# Branch Agent Skill

This skill offers a reusable BranchAgent node for dynamic context branching, including exploration, evaluation, and merging.

## Features
- Parallel branch execution.
- LLM-based evaluation and merging.
- Integration with context manager for compression.

## Usage
Load for complex query handling. Provides branching logic with tool support.

## Implementation
- Inspired by LangGraph multi-agent tutorials.
- Supports up to 3 branches with scoring.

## Code Examples
From LangGraph multi-agent tutorials:

```python
from langgraph.graph import StateGraph
from langgraph.types import Command

# Branch state
class BranchState(TypedDict):
    query: str
    branches: List[dict]

# Branch node
def branch_agent(state: BranchState) -> Command:
    # Create branches (e.g., different prompts)
    branches = [llm.invoke(f"Approach {i}: {state['query']}") for i in range(3)]
    # Evaluate (LLM scoring)
    scores = [llm.invoke(f"Score: {b}") for b in branches]
    best = max(zip(branches, scores), key=lambda x: x[1])
    # Merge via context manager
    merged = context_manager.merge(best[0])
    return Command(update={"result": merged})

# Build graph
builder = StateGraph(BranchState)
builder.add_node("branch", branch_agent)
graph = builder.compile()
```