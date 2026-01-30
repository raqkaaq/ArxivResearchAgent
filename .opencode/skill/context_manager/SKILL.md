# Context Manager Skill

This skill provides context compression and management utilities for long conversations in LangGraph agents, integrating with dynamic thresholds for adaptive context handling.

## Documentation
For detailed architecture and patterns, reference:
- [State Management](../../../../docs/langgraph/state.md)
- [Architecture Overview](../../../../docs/langgraph/architecture.md)
- [Messages Format](../../../../docs/langgraph/messages.md)

## Features
- Dynamic token threshold calculation based on current LLM (Ollama/Gemini).
- Summarization and pruning for long conversations.
- Endpoints for compression/merging (compress_chain, merge_into_chain).
- Integration with SQLite for conversation logs and PostgreSQL for vectorized compressions.

## Usage
Load for context handling in LangGraph agents. Supports persistence for long-horizon interactions.

## Implementation
Based on CONTEXT_PRD.md design for adaptive context compression.
Uses LLM-driven summarization (UltraGist-style) and selective pruning (ACON-style).
Hierarchical storage: short-term in checkpoint, long-term in SQLite/PostgreSQL.

## Code Examples
From Context Management design:

```python
from typing import TypedDict, List, Annotated
from langgraph.graph import StateGraph, add_messages
from langchain_core.messages import BaseMessage
from langgraph.checkpoint.memory import MemorySaver

# Context state with message accumulation
class ContextState(TypedDict):
    messages: Annotated[List[BaseMessage], add_messages]
    summary: str
    compression_needed: bool

# Dynamic threshold calculation
def calculate_threshold(state: ContextState) -> int:
    llm_context_window = 8192  # Ollama default
    reserve_ratio = 0.75
    return int(llm_context_window * reserve_ratio)

# Compress context node
def compress_context(state: ContextState):
    threshold = calculate_threshold(state)
    messages = state["messages"]
    
    if len(messages) > threshold:
        # LLM summarization
        summary = llm.invoke(f"Summarize: {messages}")
        # Keep recent messages
        return {"summary": summary, "messages": messages[-5:], "compression_needed": False}
    
    return {"compression_needed": False}

# Graph with compression
graph = StateGraph(ContextState)
graph.add_node("compress", compress_context)
graph.set_entry_point("compress")
graph.add_edge("compress", END)

# Compile with checkpointer
app = graph.compile(checkpointer=MemorySaver())

# Usage
result = app.invoke({
    "messages": [...],
    "summary": "",
    "compression_needed": False
})
```

## Integration with BranchAgent
Provides endpoints for BranchAgent to compress and merge context chains post-branching:
- `compress_chain`: Compresses long context chains
- `merge_into_chain`: Merges best branch results into main conversation