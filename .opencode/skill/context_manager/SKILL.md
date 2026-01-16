# Context Manager Skill

This skill provides context compression and management utilities for long conversations, integrating with LangGraph for dynamic thresholds and interrupts.

## Features
- Dynamic token threshold calculation based on LLM.
- Summarization and pruning nodes.
- Endpoints for compression/merging.

## Usage
Load for context handling in agent graphs. Supports real-time streaming and persistence.

## Implementation
- Based on LangGraph state management and human-in-loop how-tos.
- Includes async compression logic.

## Code Examples
From LangGraph state management how-tos:

```python
from langchain_core.messages import HumanMessage, AIMessage
from langgraph.graph import StateGraph

# Context state
class ContextState(TypedDict):
    messages: List[dict]
    summary: str

# Compress node
def compress_context(state: ContextState):
    messages = state["messages"]
    if len(messages) > 10:  # Dynamic threshold
        summary = llm.invoke(f"Summarize: {messages}")  # LLM summarization
        return {"summary": summary, "messages": messages[-5:]}  # Keep recent
    return state

# Build graph
builder = StateGraph(ContextState)
builder.add_node("compress", compress_context)
graph = builder.compile()
```