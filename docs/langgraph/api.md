# LangGraph API Reference

## Overview

Complete API reference for the LangGraph framework.

---

## StateGraph

### 1.1 Constructor

```python
class StateGraph(StateSchema: Type[TypedDict]):
    """Create a state graph
    
    Args:
        state_schema: TypedDict defining the graph's state structure
    """
```

### 1.2 Methods

```python
# Add a node
def add_node(
    self,
    node: str,
    action: Callable[..., StateUpdate],
    *,
    metadata: dict | None = None
) -> None:
    """Add a node to the graph
    
    Args:
        node: Unique name for the node
        action: Function that transforms state
        metadata: Optional metadata for the node
    """

# Add a direct edge
def add_edge(
    self,
    start_node: str,
    end_node: str
) -> None:
    """Add a direct edge between nodes
    
    Args:
        start_node: Source node name
        end_node: Target node name
    """

# Add conditional edges
def add_conditional_edges(
    self,
    start_node: str,
    condition: Callable[..., str],
    path_map: dict[str, str]
) -> None:
    """Add conditional routing
    
    Args:
        start_node: Source node name
        condition: Function that returns next node name
        path_map: Mapping of condition outputs to node names
    """

# Set entry point
def set_entry_point(self, node: str) -> None:
    """Set the entry point for the graph"""

# Set finish point (alternative to END)
def set_finish_point(self, node: str) -> None:
    """Set the finish point for the graph"""

# Compile the graph
def compile(
    self,
    *,
    checkpointer: BaseCheckpointSaver | None = None,
    interrupt_before: list[str] | None = None,
    interrupt_after: list[str] | None = None,
    state_serializer: Callable[[StateSchema], StateSchema] | None = None,
    store: Store | None = None
) -> CompiledGraph:
    """Compile the graph into an executable app
    
    Returns:
        CompiledGraph that can be invoked or streamed
    """
```

---

## CompiledGraph

### 2.1 Methods

```python
# Invoke the graph
def invoke(
    self,
    input: StateSchema,
    config: RunnableConfig | None = None
) -> StateSchema:
    """Invoke the graph with input state
    
    Returns:
        Final state after graph execution
    """

# Stream outputs
def stream(
    self,
    input: StateSchema,
    config: RunnableConfig | None = None,
    stream_mode: list[str] | None = None
) -> Iterator[dict]:
    """Stream node outputs
    
    Stream modes:
    - "values": Yield state values
    - "updates": Yield node updates
    - "messages": Yield messages
    - "debug": Yield debug info
    """

# Async invoke
async def ainvoke(
    self,
    input: StateSchema,
    config: RunnableConfig | None = None
) -> StateSchema:
    """Async invoke the graph"""

# Async stream
async def astream(
    self,
    input: StateSchema,
    config: RunnableConfig | None = None,
    stream_mode: list[str] | None = None
) -> AsyncIterator[dict]:
    """Async stream outputs"""

# Stream events
async def astream_events(
    self,
    input: StateSchema,
    config: RunnableConfig | None = None,
    version: str = "v1"
) -> AsyncIterator[dict]:
    """Stream events for monitoring"""
```

---

## Checkpointers

### 3.1 MemorySaver

```python
from langgraph.checkpoint.memory import MemorySaver

memory = MemorySaver()
# Ephemeral in-memory checkpointing
```

### 3.2 SqliteSaver

```python
from langgraph.checkpoint.sqlite import SqliteSaver

# From file
sqlite = SqliteSaver.from_conn_string("checkpoints.db")

# In-memory
sqlite = SqliteSaver.from_conn_string(":memory:")

# Methods
def get(self, config: dict, **kwargs) -> Checkpoint | None:
    """Get checkpoint"""

def put(
    self,
    config: dict,
    checkpoint: Checkpoint,
    metadata: dict,
    **kwargs
) -> dict:
    """Save checkpoint"""

def list(
    self,
    config: dict | None = None,
    **kwargs
) -> Iterator[dict]:
    """List checkpoints"""

def delete(self, config: dict, **kwargs) -> None:
    """Delete checkpoint"""
```

### 3.3 PostgresSaver

```python
from langgraph.checkpoint.postgres import PostgresSaver

# From connection string
postgres = PostgresSaver.from_conn_string(
    "postgresql://user:password@host:5432/database"
)

# With connection pool
from langgraph.checkpoint.postgres import PostgresSaver
postgres = PostgresSaver.from_conn_string(
    "postgresql://user:password@host:5432/database",
    pool_size=10,
    max_overflow=20
)
```

---

## ToolNode

```python
from langgraph.prebuilt import ToolNode

class ToolNode:
    def __init__(
        self,
        tools: list[BaseTool],
        *,
        name: str = "tools"
    ):
        """Create a tool node
    
    Args:
        tools: List of tools to make available
        name: Node name
    """
```

---

## Messages

### 4.1 HumanMessage

```python
from langchain_core.messages import HumanMessage

msg = HumanMessage(
    content: str,
    additional_kwargs: dict | None = None,
    response_metadata: dict | None = None,
    id: str | None = None
)
```

### 4.2 AIMessage

```python
from langchain_core.messages import AIMessage

msg = AIMessage(
    content: str,
    tool_calls: list[dict] | None = None,
    tool_call_id: str | None = None,
    additional_kwargs: dict | None = None,
    response_metadata: dict | None = None,
    id: str | None = None
)
```

### 4.3 SystemMessage

```python
from langchain_core.messages import SystemMessage

msg = SystemMessage(
    content: str,
    additional_kwargs: dict | None = None,
    id: str | None = None
)
```

### 4.4 ToolMessage

```python
from langchain_core.messages import ToolMessage

msg = ToolMessage(
    content: str,
    tool_call_id: str,
    additional_kwargs: dict | None = None,
    response_metadata: dict | None = None,
    id: str | None = None
)
```

---

## LLM Integration

### 5.1 ChatOpenAI

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    model: str = "gpt-4o",
    temperature: float | None = None,
    max_tokens: int | None = None,
    streaming: bool = False,
    api_key: str | None = None,
    base_url: str | None = None,
    **kwargs
)

# Methods
response = llm.invoke(messages)
stream = llm.stream(messages)
async_response = await llm.ainvoke(messages)
```

### 5.2 ChatAnthropic

```python
from langchain_anthropic import ChatAnthropic

llm = ChatAnthropic(
    model: str = "claude-sonnet-4-20250514",
    temperature: float | None = None,
    max_tokens: int | None = None,
    api_key: str | None = None,
    **kwargs
)
```

### 5.3 Binding Tools

```python
from langchain_core.tools import tool

@tool
def search(query: str) -> str:
    return "results"

llm_with_tools = llm.bind_tools([search])

# With tool choice
llm_with_tools = llm.bind_tools([search], tool_choice="search")
```

---

## Configuration

### 6.1 RunnableConfig

```python
from langchain_core.runnables import RunnableConfig

config = RunnableConfig(
    configurable: dict | None = None,
    recursion_limit: int = 25,
    max_concurrency: int | None = None,
    tags: list[str] | None = None,
    callbacks: list[BaseCallbackHandler] | None = None,
    metadata: dict | None = None
)

# Example with thread_id
config = RunnableConfig(
    configurable={"thread_id": "session_123"},
    recursion_limit=50
)
```

---

## Types

### 7.1 StateSchema

```python
from typing import TypedDict

class AgentState(TypedDict):
    input: str
    output: str | None
    messages: list[str]
```

### 7.2 StateUpdate

```python
from typing import TypedDict

class AgentState(TypedDict):
    result: str

# Node returns partial update
def node(state: AgentState) -> AgentState:
    return {"result": "processed"}
```

---

## Exceptions

### 8.1 Exception Types

```python
from langgraph.errors import (
    GraphRecursionError,      # Too many recursion
    InvalidStateError,        # Invalid state update
    NodeInterrupt,            # Node interrupted
    EmptyInputError,          # Empty input provided
)
```

---

## Summary

| Module | Key Classes |
|--------|-------------|
| `graph` | StateGraph, END, START, add_messages |
| `checkpoint` | MemorySaver, SqliteSaver, PostgresSaver |
| `prebuilt` | ToolNode |
| `messages` | HumanMessage, AIMessage, SystemMessage, ToolMessage |
| `errors` | GraphRecursionError, InvalidStateError |

---

*Document Version: 1.0*
*Last Updated: January 2026*
