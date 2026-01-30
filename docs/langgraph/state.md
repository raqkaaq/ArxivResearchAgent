# LangGraph State Management

## Overview

State management in LangGraph is built around **TypedDict**-based state with **checkpointing** for persistence. This document covers state definition, updates, reducers, and persistence mechanisms.

---

## State Definition

### 1.1 Basic TypedDict State

```python
from typing import TypedDict, List, Dict, Optional

class AgentState(TypedDict):
    """State for a research agent"""
    input: str                    # Required: user input
    messages: List[str]           # Required: conversation history
    context: Dict[str, any]       # Optional: additional context
    result: Optional[str]         # Optional: final result
    confidence: Optional[float]   # Optional: confidence score
```

### 1.2 Required vs Optional Fields

```python
from typing import TypedDict, NotRequired, Required

class ResearchState(TypedDict):
    # Required fields (no default)
    query: Required[str]
    papers: Required[List[Dict]]
    
    # Optional fields (have default of None)
    summary: NotRequired[str]
    citations: NotRequired[int]
    metadata: NotRequired[Dict[str, any]]
```

### 1.3 Nested State Structures

```python
from typing import TypedDict, List
from datetime import datetime

class PaperInfo(TypedDict):
    id: str
    title: str
    authors: List[str]
    abstract: str
    year: int

class CitationInfo(TypedDict):
    paper_id: str
    citations: int
    h_index: float

class ResearchState(TypedDict):
    query: str
    papers: List[PaperInfo]
    citations: List[CitationInfo]
    summary: str
    metadata: Dict[str, datetime]
```

---

## State Updates

### 2.1 Returning Partial Updates

Nodes return partial state updates:

```python
def process_query(state: ResearchState) -> ResearchState:
    """Process user query"""
    query = state["query"]
    
    # Do processing
    processed_query = preprocess(query)
    
    # Return only the fields to update
    return {
        "query": processed_query,
        "metadata": {"processed_at": datetime.now()}
    }

def search_papers(state: ResearchState) -> ResearchState:
    """Search for papers"""
    results = arxiv_search(state["query"])
    
    return {
        "papers": results,
        "metadata": {"searched_at": datetime.now()}
    }
```

### 2.2 Accumulating Values

For lists that should accumulate:

```python
def collect_results(state: ResearchState) -> ResearchState:
    new_results = search_arxiv(state["query"])
    
    # Accumulate with existing papers
    return {
        "papers": state["papers"] + new_results,
        "metadata": {"last_update": datetime.now()}
    }

def analyze_papers(state: ResearchState) -> ResearchState:
    """Analyze all collected papers"""
    analyses = []
    for paper in state["papers"]:
        analysis = analyze(paper)
        analyses.append(analysis)
    
    return {
        "citations": analyses,
        "summary": generate_summary(analyses)
    }
```

### 2.3 Conditional Updates

```python
def conditional_process(state: AgentState) -> AgentState:
    """Update based on conditions"""
    if state["confidence"] and state["confidence"] > 0.9:
        return {"result": "high_confidence_result"}
    elif state["confidence"] and state["confidence"] > 0.5:
        return {"result": "medium_confidence_result"}
    else:
        return {"result": "needs_review"}
```

---

## Reducers

### 3.1 Using Annotated with Reducers

```python
from typing import TypedDict, Annotated
from langgraph.graph import add_messages
from langchain_core.messages import BaseMessage

class ConversationState(TypedDict):
    # Messages will be appended, not replaced
    messages: Annotated[List[BaseMessage], add_messages]
    context: Dict[str, any]

def add_user_message(state: ConversationState, message: str) -> ConversationState:
    """Add a user message"""
    return {"messages": [HumanMessage(content=message)]}

def add_assistant_message(state: ConversationState, message: str) -> ConversationState:
    """Add an assistant message"""
    return {"messages": [AIMessage(content=message)]}
```

### 3.2 Custom Reducers

```python
from typing import TypedDict, Annotated, List
from operator import add as list_add

class ScoreState(TypedDict):
    scores: Annotated[List[float], lambda a, b: a + b]
    metadata: Dict[str, list]

def add_score(state: ScoreState, score: float) -> ScoreState:
    """Add a score to the list"""
    return {"scores": [score], "metadata": {"scores_added": [datetime.now()]}}

def combine_results(state1: ScoreState, state2: ScoreState) -> ScoreState:
    """Custom reducer for combining states"""
    return {
        "scores": state1["scores"] + state2["scores"],
        "metadata": {
            "from_state1": state1["metadata"],
            "from_state2": state2["metadata"]
        }
    }
```

### 3.3 Multiple Reducers

```python
from typing import TypedDict, Annotated
from langgraph.graph import add_messages

class ComplexState(TypedDict):
    # Accumulates messages
    messages: Annotated[List[dict], add_messages]
    # Replaces on each update
    current_task: str
    # Accumulates with custom function
    metrics: Annotated[List[float], lambda a, b: a + b]
```

---

## Checkpointing

### 4.1 Memory Checkpointer (Ephemeral)

```python
from langgraph.checkpoint.memory import MemorySaver

memory = MemorySaver()

app = graph.compile(checkpointer=memory)

# Run with checkpointing
config = {"configurable": {"thread_id": "session_123"}}
result = app.invoke({"input": "hello"}, config=config)

# Resume with same config
result = app.invoke(None, config=config)
```

### 4.2 SQLite Checkpointer (Persistent)

```python
from langgraph.checkpoint.sqlite import SqliteSaver

# In-memory SQLite
sqlite = SqliteSaver.from_conn_string(":memory:")

# File-based SQLite
sqlite = SqliteSaver.from_conn_string("checkpoints.db")

app = graph.compile(checkpointer=sqlite)

# Checkpoints persist across restarts
```

### 4.3 PostgreSQL Checkpointer (Distributed)

```python
from langgraph.checkpoint.postgres import PostgresSaver

postgres = PostgresSaver.from_conn_string(
    "postgresql://user:password@localhost:5432/langgraph"
)

# For connection pooling
from langgraph.checkpoint.postgres import PostgresSaver
postgres = PostgresSaver.from_conn_string(
    "postgresql://user:password@localhost:5432/langgraph",
    pool_size=10
)

app = graph.compile(checkpointer=postgres)
```

### 4.4 Custom Checkpointer

```python
from langgraph.checkpoint.base import BaseCheckpointSaver, Checkpoint

class CustomCheckpointer(BaseCheckpointSaver):
    def put(self, config, checkpoint, metadata, **kwargs) -> dict:
        """Save a checkpoint"""
        # Custom save logic
        return {"configurable": {"thread_id": config["configurable"]["thread_id"]}}
    
    def get(self, config, **kwargs) -> Checkpoint | None:
        """Get a checkpoint"""
        # Custom load logic
        return checkpoint
    
    def list(self, config, **kwargs) -> List[dict]:
        """List checkpoints"""
        # Custom list logic
        return []
```

---

## Time Travel

### 5.1 Listing Checkpoints

```python
config = {"configurable": {"thread_id": "session_123"}}

# List all checkpoints
checkpoints = []
for checkpoint in app.checkpointer.list(config):
    checkpoints.append(checkpoint)
    print(f"ID: {checkpoint['id']}, Created: {checkpoint['metadata']['created_at']}")
```

### 5.2 Replaying from Checkpoint

```python
# Get a specific checkpoint
checkpoint_id = "checkpoint-abc-123"
config = {
    "configurable": {
        "thread_id": "session_123",
        "checkpoint_id": checkpoint_id
    }
}

# Replay from this checkpoint
for event in app.stream(None, config=config):
    print(event)
```

### 5.3 Branching from Checkpoint

```python
# Get checkpoint to branch from
checkpoint = app.checkpointer.get(config)

# Create new config with same thread_id but different branch
branch_config = {
    "configurable": {
        "thread_id": "session_123",
        "checkpoint_id": checkpoint["id"]
    }
}

# Run with different logic
result = app.invoke({"input": "explore alternative"}, config=branch_config)
```

---

## State Configuration

### 6.1 Thread Management

```python
# Multiple independent conversations
configs = [
    {"configurable": {"thread_id": "conversation_1"}},
    {"configurable": {"thread_id": "conversation_2"}},
    {"configurable": {"thread_id": "conversation_3"}},
]

for config in configs:
    result = app.invoke(initial_state, config=config)
```

### 6.2 Recursion Limits

```python
from langchain_core.runnables import RunnableConfig

config = RunnableConfig(
    configurable={"thread_id": "session_123"},
    recursion_limit=50,  # Prevent infinite loops
    max_concurrency=10   # Limit concurrent executions
)

result = app.invoke(state, config=config)
```

### 6.3 State Sanitization

```python
from langgraph.graph import StateGraph, START, END

class SecureState(TypedDict):
    user_input: str
    # Sensitive fields should not be checkpointed
    api_keys: NotRequired[Dict[str, str]]

def sanitize_state(state: SecureState) -> SecureState:
    """Remove sensitive data before checkpointing"""
    sanitized = state.copy()
    if "api_keys" in sanitized:
        del sanitized["api_keys"]
    return sanitized

# Use state_serializer in compile
app = graph.compile(
    checkpointer=memory,
    state_serializer=sanitize_state
)
```

---

## Best Practices

### 7.1 State Design

1. **Keep State Minimal**
   ```python
   # Good: Store raw data, compute derived values
   class GoodState(TypedDict):
       messages: List[BaseMessage]
       search_results: List[Dict]
   
   # Bad: Store derivable data
   class BadState(TypedDict):
       messages: List[BaseMessage]
       last_message_summary: str  # Can be computed
   ```

2. **Use Type Hints**
   ```python
   class TypedState(TypedDict, total=False):
       # Clear about what types are expected
       input: str
       output: Optional[str]
   ```

3. **Version Your State**
   ```python
   class ResearchState(TypedDict):
       version: int  # Track state version for migrations
       data: Dict[str, any]
   ```

### 7.2 Checkpoint Management

1. **Regular Checkpoints**
   ```python
   # Checkpoint after important operations
   def important_node(state: State) -> State:
       result = do_important_work(state)
       return result
   ```

2. **Cleanup Old Checkpoints**
   ```python
   # Periodically clean old checkpoints
   app.checkpointer.delete_old_checkpoints(
       thread_id="session_123",
       keep_last=10
   )
   ```

### 7.3 Error Recovery

```python
try:
    result = app.invoke(state, config=config)
except RecursionError:
    # Too many recursions - reset with checkpoint
    result = app.invoke(state, config={
        **config,
        "recursion_limit": 100
    })
except Exception as e:
    # Recover from last checkpoint
    last_checkpoint = app.checkpointer.get(config)
    result = app.invoke(last_checkpoint.state, config=config)
```

---

## Summary

| Feature | Description |
|---------|-------------|
| TypedDict State | Type-safe state definition |
| Partial Updates | Nodes return only changed fields |
| Reducers | Custom accumulation logic |
| Memory Checkpointer | Ephemeral state persistence |
| SQLite Checkpointer | File-based persistence |
| Postgres Checkpointer | Distributed persistence |
| Time Travel | Replay and branch from checkpoints |
| Thread Management | Multiple independent conversations |

---

*Document Version: 1.0*
*Last Updated: January 2026*
