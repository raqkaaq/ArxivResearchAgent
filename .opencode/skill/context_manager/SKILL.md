# Context Manager Skill

This skill provides context compression and management utilities for long conversations in Orchestral AI agents, integrating with dynamic thresholds for adaptive context handling.

## Documentation
For detailed architecture and patterns, reference:
- [Context Management](../../../../docs/orchestral_ai/context.md)
- [Architecture Overview](../../../../docs/orchestral_ai/architecture.md)
- [Messages Format](../../../../docs/orchestral_ai/messages.md)

## Features
- Dynamic token threshold calculation based on current LLM (Ollama/Gemini).
- Summarization and pruning for long conversations.
- Endpoints for compression/merging (compress_chain, merge_into_chain).
- Integration with SQLite for conversation logs and PostgreSQL for vectorized compressions.

## Usage
Load for context handling in Orchestral AI agents. Supports persistence for long-horizon interactions.

## Implementation
- Based on CONTEXT_PRD.md design for adaptive context compression.
- Uses LLM-driven summarization (UltraGist-style) and selective pruning (ACON-style).
- Hierarchical storage: short-term in-window, long-term in SQLite/PostgreSQL.

## Code Examples
From Context Management design:

```python
from orchestral.context import Context
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

# Compress context
def compress_context(state: ContextState):
    threshold = calculate_threshold(state)
    messages = state["messages"]
    
    if len(messages) > threshold:
        # LLM summarization
        summary = llm.invoke(f"Summarize: {messages}")
        # Keep recent messages
        return {"summary": summary, "messages": messages[-5:], "compression_needed": False}
    
    return {"compression_needed": False}
```

## Integration with BranchAgent
Provides endpoints for BranchAgent to compress and merge context chains post-branching:
- `compress_chain`: Compresses long context chains
- `merge_into_chain`: Merges best branch results into main conversation