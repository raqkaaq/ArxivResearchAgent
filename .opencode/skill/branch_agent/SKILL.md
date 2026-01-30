# Branch Agent Skill

This skill offers a reusable branching pattern for dynamic context branching in LangGraph graphs, including exploration, evaluation, and merging of multiple approaches.

## Documentation
For detailed architecture and patterns, reference:
- [Architecture Overview](../../../../docs/langgraph/architecture.md)
- [State Management](../../../../docs/langgraph/state.md)
- [Nodes and Edges](../../../../docs/langgraph/nodes_edges.md)
- [Examples](../../../../docs/langgraph/examples.md)

## Features
- Parallel branch execution with configurable strategies.
- LLM-based evaluation and scoring of branch results.
- Integration with context manager for compression and merging.
- Support for multiple branches with relevance scoring.

## Usage
Load for complex query handling in LangGraph agents. Provides branching logic with tool support for exploring multiple approaches.

## Implementation
Inspired by BranchAgent design from AGENT_PRD.md.
Supports different RAG strategies or prompt variants.
Uses state updates and conditional edges for routing between branches.

## Code Examples
From LangGraph branching patterns:

```python
from typing import TypedDict, List, Literal
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI

# Branch state definition
class BranchState(TypedDict):
    query: str
    branches: List[dict]
    evaluated_results: List[dict]
    best_result: dict | None

# Branch node implementation
def branch_agent(state: BranchState):
    # Create branches (e.g., different strategies)
    branches = [
        {"name": "standard_rag", "strategy": "vector_search"},
        {"name": "graph_enhanced", "strategy": "hybrid_retrieval"},
        {"name": "speculative", "strategy": "hyde_generation"}
    ]
    
    # Execute branches (could be parallel or sequential)
    results = execute_branches(branches, state["query"])
    
    return {"branches": results}

# Evaluate branches
def evaluate_branches(state: BranchState):
    # LLM-based evaluation
    best = evaluate_and_select(state["branches"])
    return {"best_result": best}

# Graph with branching
graph = StateGraph(BranchState)
graph.add_node("branch", branch_agent)
graph.add_node("evaluate", evaluate_branches)

graph.set_entry_point("branch")
graph.add_edge("branch", "evaluate")
graph.add_edge("evaluate", END)
```

## Trigger Conditions
Branching activates based on heuristics:
- Query length > 50 tokens (complex query)
- Low confidence in initial retrieval (< 0.7 relevance score)
- User explicitly requests "explore options" or "compare approaches"
- High entropy in query (ambiguous intent)