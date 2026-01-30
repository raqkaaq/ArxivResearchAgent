# Context Manager Skill

This skill provides context compression and management utilities for long conversations in Orchestral AI graphs, integrating with dynamic thresholds and interrupts for adaptive context handling.

## Features
- Dynamic token threshold calculation based on current LLM (Ollama/Gemini).
- Summarization and pruning nodes for long conversations.
- Endpoints for compression/merging (compress_chain, merge_into_chain).
- Integration with SQLite for conversation logs and PostgreSQL for vectorized compressions.

## Usage
Load for context handling in Orchestral AI agent graphs. Supports real-time streaming and persistence for long-horizon interactions.

## Implementation
- Based on CONTEXT_PRD.md design for adaptive context compression.
- Uses LLM-driven summarization (UltraGist-style) and selective pruning (ACON-style).
- Hierarchical storage: short-term in-window, long-term in SQLite/PostgreSQL.

## Code Examples
From Context Management design:

```python
from orchestral_ai import Graph, AgentNode
from typing import TypedDict, List

# Context state
class ContextState(TypedDict):
    messages: List[dict]
    summary: str
    compression_needed: bool

# Dynamic threshold calculation
def calculate_threshold(state: ContextState) -> int:
    llm_context_window = 8192  # Ollama default
    reserve_ratio = 0.75
    return int(llm_context_window * reserve_ratio)

# Compress node
def compress_context(state: ContextState):
    threshold = calculate_threshold(state)
    messages = state["messages"]
    
    if len(messages) > threshold:
        # LLM summarization
        summary = llm.invoke(f"Summarize: {messages}")
        # Keep recent messages
        return {"summary": summary, "messages": messages[-5:], "compression_needed": False}
    
    return {"compression_needed": False}

# Build graph
graph = Graph(
    nodes=[
        AgentNode(name="context_monitor", monitor_context),
        AgentNode(name="compress", compress_context),
    ]
)
```

## Integration with BranchAgent
Provides endpoints for BranchAgent to compress and merge context chains post-branching:
- `compress_chain`: Compresses long context chains
- `merge_into_chain`: Merges best branch results into main conversation