# LangGraph Messages

## Overview

LangGraph uses LangChain's message system for conversation state. This document covers message types, formats, and state representation in LangGraph.

---

## Message Types

### 1.1 Basic Messages

```python
from langchain_core.messages import (
    HumanMessage,
    AIMessage,
    SystemMessage,
    ToolMessage,
    BaseMessage
)

# Human message (user input)
human_msg = HumanMessage(content="What is machine learning?")

# AI message (assistant response)
ai_msg = AIMessage(content="Machine learning is a subset of AI...")

# System message (instructions)
system_msg = SystemMessage(content="You are a helpful research assistant.")

# Tool message (tool execution result)
tool_msg = ToolMessage(
    content="Search results for machine learning papers...",
    tool_call_id="call_123"
)
```

### 1.2 Message with Tool Calls

```python
from langchain_core.messages import AIMessage

# AI message with tool calls
ai_with_tools = AIMessage(
    content="I'll search for relevant papers.",
    tool_calls=[
        {
            "id": "call_123",
            "name": "search_arxiv",
            "args": {"query": "machine learning", "max_results": 5}
        }
    ]
)

# Tool message responding to tool call
tool_response = ToolMessage(
    content="Found 5 papers...",
    tool_call_id="call_123"
)
```

### 1.3 Message Metadata

```python
from langchain_core.messages import HumanMessage

# Messages with metadata
msg = HumanMessage(
    content="Research papers on neural networks",
    additional_kwargs={
        "metadata": {"source": "cli", "session": "123"},
        "citation_count": 5
    }
)
```

---

## State Representation

### 2.1 TypedDict for Messages

```python
from typing import TypedDict, List, Annotated
from langchain_core.messages import BaseMessage
from langgraph.graph import add_messages

class AgentState(TypedDict):
    """State with message history"""
    messages: Annotated[List[BaseMessage], add_messages]
    context: dict | None
    result: str | None

# Usage in node
def process(state: AgentState) -> AgentState:
    messages = state["messages"]
    last_message = messages[-1]
    
    return {"messages": [AIMessage(content="Response")]}
```

### 2.2 Message Serialization

```python
from langchain_core.messages import HumanMessage, AIMessage
import json

# Serialize messages to JSON
def serialize_messages(messages: List[BaseMessage]) -> List[dict]:
    return [msg.model_dump() for msg in messages]

# Deserialize from JSON
def deserialize_messages(data: List[dict]) -> List[BaseMessage]:
    messages = []
    for msg_data in data:
        msg_type = msg_data.get("type", "human")
        if msg_type == "human":
            messages.append(HumanMessage(**msg_data))
        elif msg_type == "ai":
            messages.append(AIMessage(**msg_data))
    return messages

# Save to file
with open("conversation.json", "w") as f:
    json.dump(serialize_messages(messages), f, indent=2)

# Load from file
with open("conversation.json", "r") as f:
    data = json.load(f)
    messages = deserialize_messages(data)
```

### 2.3 Checkpointing Messages

```python
from langgraph.checkpoint.memory import MemorySaver

memory = MemorySaver()

class ConversationState(TypedDict):
    messages: Annotated[List[BaseMessage], add_messages]

# Checkpointer saves message history
app = graph.compile(checkpointer=memory)

# Each invoke checkpoints messages
config = {"configurable": {"thread_id": "session_123"}}
app.invoke({"messages": [HumanMessage(content="Hello")]}, config=config)
app.invoke({"messages": [HumanMessage(content="How are you?")]}, config=config)

# Load checkpoint
checkpoint = app.checkpointer.get(config)
print(checkpoint["state"]["messages"])
# Output: [HumanMessage("Hello"), AIMessage("..."), HumanMessage("How are you?")]
```

---

## Message Flow

### 3.1 Basic Conversation Flow

```python
from typing import TypedDict
from langchain_core.messages import HumanMessage, AIMessage

class ChatState(TypedDict):
    messages: list[str]

def agent(state: ChatState) -> ChatState:
    """Simple agent that echoes"""
    user_input = state["messages"][-1]
    response = f"You said: {user_input}"
    return {"messages": state["messages"] + [response]}
```

### 3.2 Multi-Turn with Tools

```python
from typing import TypedDict, List
from langchain_core.messages import HumanMessage, AIMessage, ToolMessage

class ToolState(TypedDict):
    messages: List[HumanMessage | AIMessage | ToolMessage]
    intermediate_steps: List[dict]

def agent_node(state: ToolState) -> ToolState:
    """Agent that can call tools"""
    messages = state["messages"]
    
    # Get LLM response with potential tool calls
    response = llm_with_tools.invoke(messages)
    
    return {"messages": [response]}

def tool_node(state: ToolState) -> ToolState:
    """Execute tool calls"""
    messages = state["messages"]
    last_msg = messages[-1]
    
    if hasattr(last_msg, "tool_calls") and last_msg.tool_calls:
        tool_results = []
        for call in last_msg.tool_calls:
            result = execute_tool(call["name"], call["args"])
            tool_results.append(
                ToolMessage(content=str(result), tool_call_id=call["id"])
            )
        return {"messages": messages + tool_results}
    
    return state
```

### 3.3 Message Pruning

```python
from typing import TypedDict, Annotated, List
from langchain_core.messages import BaseMessage
from langgraph.graph import add_messages

class PrunedState(TypedDict):
    messages: Annotated[List[BaseMessage], add_messages]

def compress_messages(state: PrunedState, max_tokens: int = 8000) -> PrunedState:
    """Compress message history to fit context window"""
    messages = state["messages"]
    
    # Calculate current tokens
    current_tokens = sum(len(msg.content.split()) for msg in messages)
    
    if current_tokens <= max_tokens:
        return state
    
    # Keep system message and recent messages
    system_msg = None
    recent_messages = []
    
    for msg in messages:
        if isinstance(msg, SystemMessage):
            system_msg = msg
        else:
            recent_messages.append(msg)
    
    # Keep last N messages
    kept = [system_msg] if system_msg else []
    kept.extend(recent_messages[-10:])  # Last 10 messages
    
    return {"messages": [m for m in kept if m is not None]}
```

---

## Message Templates

### 4.1 System Prompts

```python
from langchain_core.messages import SystemMessage

RESEARCH_ASSISTANT_PROMPT = SystemMessage(content="""You are a research assistant 
specialized in academic papers. Help users find, analyze, and understand research 
papers. Always cite your sources and provide links to the original papers.""")

CODING_ASSISTANT_PROMPT = SystemMessage(content="""You are a coding assistant. 
Help users write, debug, and improve code. Always explain your reasoning and 
provide working code examples.""")
```

### 4.2 Few-Shot Examples

```python
from langchain_core.messages import HumanMessage, AIMessage

FEW_SHOT_EXAMPLES = [
    HumanMessage(content="What is quantum computing?"),
    AIMessage(content="Quantum computing uses quantum bits (qubits) that can exist in superposition states..."),
    HumanMessage(content="How is this different from classical computing?"),
    AIMessage(content="Classical computers use binary bits (0 or 1), while quantum computers leverage..."),
]

def get_few_shot_messages(topic: str) -> List[BaseMessage]:
    """Get few-shot examples for a topic"""
    return [
        SystemMessage(content=f"Answer questions about {topic} with detailed explanations."),
        *FEW_SHOT_EXAMPLES,
    ]
```

---

## Integration with State

### 5.1 Message in State Graph

```python
from typing import TypedDict, Annotated
from langgraph.graph import StateGraph, END, add_messages

class MultiModalState(TypedDict):
    # Messages accumulate
    messages: Annotated[List[dict], add_messages]
    # Current task
    task: str
    # Results
    output: str | None

graph = StateGraph(MultiModalState)
graph.add_node("process", process_node)
graph.add_node("respond", respond_node)

graph.set_entry_point("process")
graph.add_edge("process", "respond")
graph.add_edge("respond", END)

app = graph.compile()
```

### 5.2 Message Persistence

```python
from langgraph.checkpoint.sqlite import SqliteSaver

sqlite = SqliteSaver.from_conn_string("conversations.db")

class PersistedState(TypedDict):
    messages: Annotated[List[dict], add_messages]

app = graph.compile(
    checkpointer=sqlite,
    store=["conversations"]  # For conversation storage
)

# Save conversation
config = {"configurable": {"thread_id": "user_123"}}
app.invoke({"messages": [HumanMessage(content="Hello")]}, config=config)

# Later: load conversation
checkpoint = app.checkpointer.get(config)
```

---

## Best Practices

### 5.1 Message Design

1. **Keep Messages Focused**
   ```python
   # Good: Single purpose
   HumanMessage(content="Search for papers on transformers")
   
   # Bad: Multiple requests
   HumanMessage(content="Search for papers, also summarize this paper, and find citations")
   ```

2. **Include Context**
   ```python
   HumanMessage(
       content="Find recent papers on attention mechanisms",
       additional_kwargs={
           "filters": {"year": 2024, "venue": "NeurIPS"}
       }
   )
   ```

3. **Track Tool Calls**
   ```python
   # Clear tool call structure
   AIMessage(
       content="Searching for papers...",
       tool_calls=[{
           "id": "search_1",
           "name": "search_arxiv",
           "args": {"query": "attention mechanisms", "year": 2024}
       }]
   )
   ```

### 5.2 State Optimization

```python
def optimize_state(state: AgentState) -> AgentState:
    """Remove unnecessary data from state"""
    # Keep only essential message data
    messages = [
        {
            "type": msg.type,
            "content": msg.content[:1000] if hasattr(msg, 'content') else str(msg)[:1000],
        }
        for msg in state["messages"][-20:]  # Last 20 messages
    ]
    
    return {"messages": messages}
```

---

## Summary

| Message Type | Description |
|--------------|-------------|
| HumanMessage | User input |
| AIMessage | Assistant response |
| SystemMessage | Instructions |
| ToolMessage | Tool execution result |
| add_messages | Reducer for accumulating messages |

---

*Document Version: 1.0*
*Last Updated: January 2026*
