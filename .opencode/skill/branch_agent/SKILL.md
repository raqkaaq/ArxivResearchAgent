# Branch Agent Skill

This skill offers a reusable BranchAgent for dynamic context branching in Orchestral AI graphs, including exploration, evaluation, and merging of multiple approaches.

## Documentation
For detailed architecture and patterns, reference:
- [Architecture Overview](../../../../docs/orchestral_ai/architecture.md)
- [Context Management](../../../../docs/orchestral_ai/context.md)
- [Examples](../../../../docs/orchestral_ai/examples.md)

## Features
- Parallel branch execution with configurable strategies.
- LLM-based evaluation and scoring of branch results.
- Integration with context manager for compression and merging.
- Support for up to 3 branches with relevance scoring.

## Usage
Load for complex query handling in Orchestral AI agents. Provides branching logic with tool support for exploring multiple approaches.

## Implementation
- Inspired by BranchAgent design from AGENT_PRD.md.
- Supports different RAG strategies or prompt variants.
- Uses state updates for routing between branches.

## Code Examples
From BranchAgent design patterns:

```python
from typing import TypedDict, List

# Branch state definition
class BranchState(TypedDict):
    query: str
    branches: List[dict]
    evaluated_results: List[dict]

# Branch node implementation
def branch_agent(state: BranchState):
    # Create branches (e.g., different strategies)
    branches = [
        {"name": "standard_rag", "strategy": "vector_search"},
        {"name": "graph_enhanced", "strategy": "hybrid_retrieval"},
        {"name": "speculative", "strategy": "hyde_generation"}
    ]
    
    # Execute branches in parallel
    results = execute_parallel_branches(branches, state["query"])
    
    return {
        "branches": results,
        "next": "evaluate"
    }
```

## Trigger Conditions
BranchAgent activates based on heuristics:
- Query length > 50 tokens (complex query)
- Low confidence in initial retrieval (< 0.7 relevance score)
- User explicitly requests "explore options" or "compare approaches"
- High entropy in query (ambiguous intent)