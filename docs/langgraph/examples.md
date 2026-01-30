# LangGraph Examples

## Overview

This document provides comprehensive code examples for common LangGraph use cases.

---

## Quick Examples

### 1.1 Minimal Graph (5 lines)

```python
from typing import TypedDict
from langgraph.graph import StateGraph, END

class SimpleState(TypedDict):
    input: str
    output: str

def node(state: SimpleState) -> SimpleState:
    return {"input": state["input"], "output": f"Echo: {state['input']}"}

graph = StateGraph(SimpleState)
graph.add_node("node", node)
graph.set_entry_point("node")
graph.add_edge("node", END)

app = graph.compile()
result = app.invoke({"input": "Hello"})
print(result)  # {'input': 'Hello', 'output': 'Echo: Hello'}
```

### 1.2 Basic Agent

```python
from typing import TypedDict, List
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, HumanMessage

class AgentState(TypedDict):
    messages: List[str]
    result: str | None

llm = ChatOpenAI(model="gpt-4o")

def agent(state: AgentState) -> AgentState:
    messages = [SystemMessage(content="You are a helpful assistant.")]
    messages.extend([HumanMessage(content=m) for m in state["messages"]])
    
    response = llm.invoke(messages)
    return {"messages": state["messages"], "result": response.content}

graph = StateGraph(AgentState)
graph.add_node("agent", agent)
graph.set_entry_point("agent")
graph.add_edge("agent", END)

app = graph.compile()
result = app.invoke({"messages": ["What is AI?"], "result": None})
print(result["result"])
```

### 1.3 With Cost Tracking

```python
from typing import TypedDict, List
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI

class TrackedState(TypedDict):
    input: str
    output: str
    cost: float | None

llm = ChatOpenAI(model="gpt-4o")

def track_cost(func):
    def wrapper(state):
        import time
        start = time.time()
        result = func(state)
        elapsed = time.time() - start
        cost = (elapsed * 0.01)  # Simplified cost model
        return {**result, "cost": cost}
    return wrapper

@track_cost
def agent(state: TrackedState) -> TrackedState:
    response = llm.invoke(state["input"])
    return {"input": state["input"], "output": response.content, "cost": None}

graph = StateGraph(TrackedState)
graph.add_node("agent", agent)
graph.set_entry_point("agent")
graph.add_edge("agent", END)

app = graph.compile()
result = app.invoke({"input": "Hello", "output": None, "cost": None})
print(f"Response: {result['output']}")
print(f"Cost: ${result['cost']:.4f}")
```

---

## Tool Examples

### 2.1 Custom Tool Definition

```python
from langchain_core.tools import tool
from typing import TypedDict, List

@tool
def search_arxiv(query: str, max_results: int = 5) -> str:
    """Search arXiv for papers"""
    # Implementation
    return f"Found papers for: {query}"

@tool
def analyze_paper(paper_id: str) -> dict:
    """Analyze a paper by ID"""
    return {"id": paper_id, "title": "Sample Paper", "citations": 42}

class ResearchState(TypedDict):
    query: str
    papers: List[dict]
    results: str | None

def research_node(state: ResearchState) -> ResearchState:
    # Use tools
    search_result = search_arxiv.invoke({"query": state["query"], "max_results": 10})
    analysis = analyze_paper.invoke({"paper_id": "1234.5678"})
    
    return {
        "query": state["query"],
        "papers": [analysis],
        "results": search_result
    }
```

### 2.2 Using ToolNode

```python
from typing import TypedDict, List
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode
from langchain_openai import ChatOpenAI
from langchain_core.tools import tool

@tool
def calculate(a: int, b: int, operation: str = "add") -> int:
    """Perform calculation"""
    if operation == "add":
        return a + b
    elif operation == "multiply":
        return a * b
    return a - b

tools = [calculate]
tool_node = ToolNode(tools)

llm = ChatOpenAI(model="gpt-4o")
llm_with_tools = llm.bind_tools(tools)

class ToolState(TypedDict):
    messages: List[str]
    intermediate_steps: List[dict]

def agent(state: ToolState) -> ToolState:
    response = llm_with_tools.invoke(state["messages"])
    return {"messages": [response.content], "intermediate_steps": []}

def should_continue(state: ToolState) -> str:
    last_msg = state["messages"][-1]
    if "calculate" in last_msg.lower():
        return "tools"
    return "end"

graph = StateGraph(ToolState)
graph.add_node("agent", agent)
graph.add_node("tools", tool_node)

graph.set_entry_point("agent")
graph.add_conditional_edges("agent", should_continue, {"tools": "tools", "end": END})
graph.add_edge("tools", "agent")

app = graph.compile()
```

---

## Streaming Examples

### 3.1 Basic Streaming

```python
from typing import TypedDict
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI

class StreamState(TypedDict):
    input: str
    output: str | None

llm = ChatOpenAI(model="gpt-4o")

def stream_node(state: StreamState) -> StreamState:
    response = llm.invoke(state["input"])
    return {"input": state["input"], "output": response.content}

graph = StateGraph(StreamState)
graph.add_node("stream", stream_node)
graph.set_entry_point("stream")
graph.add_edge("stream", END)

app = graph.compile()

# Stream output
for chunk in app.stream({"input": "Write a story about AI"}):
    print(chunk)
```

### 3.2 Streaming with Events

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(model="gpt-4o")

async def stream_with_events():
    async for event in app.astream_events(
        {"input": "Hello"}, version="v1"
    ):
        kind = event["event"]
        if kind == "on_chat_model_stream":
            print(event["data"]["chunk"].content, end="", flush=True)
```

---

## Multi-Turn Conversation

### 4.1 Simple Conversation

```python
from typing import TypedDict, List, Annotated
from langgraph.graph import StateGraph, END, add_messages
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, AIMessage

class ConversationState(TypedDict):
    messages: Annotated[List[HumanMessage | AIMessage], add_messages]

llm = ChatOpenAI(model="gpt-4o")

def agent(state: ConversationState) -> ConversationState:
    response = llm.invoke(state["messages"])
    return {"messages": [response]}

graph = StateGraph(ConversationState)
graph.add_node("agent", agent)
graph.set_entry_point("agent")
graph.add_edge("agent", END)

app = graph.compile()

# First turn
result1 = app.invoke({"messages": [HumanMessage(content="What is Python?")]})
print(result1["messages"][-1].content)

# Second turn (context maintained)
result2 = app.invoke(
    {"messages": [HumanMessage(content="How do I install it?")]},
    config={"configurable": {"thread_id": "conversation_1"}}
)
print(result2["messages"][-1].content)
```

### 4.2 Multi-Agent Conversation

```python
from typing import TypedDict, Literal, List
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, AIMessage

class DebateState(TypedDict):
    topic: str
    position_a: str | None
    position_b: str | None
    round: int
    final_position: str | None

llm = ChatOpenAI(model="gpt-4o")

def agent_a(state: DebateState) -> DebateState:
    prompt = f"Argue for: {state['topic']}"
    response = llm.invoke([HumanMessage(content=prompt)])
    return {"position_a": response.content, "round": state["round"] + 1}

def agent_b(state: DebateState) -> DebateState:
    prompt = f"Argue against: {state['topic']}"
    response = llm.invoke([HumanMessage(content=prompt)])
    return {"position_b": response.content, "round": state["round"] + 1}

def synthesize(state: DebateState) -> DebateState:
    prompt = f"Synthesize these positions:\nFor: {state['position_a']}\nAgainst: {state['position_b']}"
    response = llm.invoke([HumanMessage(content=prompt)])
    return {"final_position": response.content}

graph = StateGraph(DebateState)
graph.add_node("agent_a", agent_a)
graph.add_node("agent_b", agent_b)
graph.add_node("synthesize", synthesize)

graph.set_entry_point("agent_a")
graph.add_edge("agent_a", "agent_b")
graph.add_edge("agent_b", "synthesize")
graph.add_edge("synthesize", END)

app = graph.compile()
result = app.invoke({"topic": "AI will replace jobs", "round": 0, "position_a": None, "position_b": None, "final_position": None})
```

---

## Persistence Examples

### 5.1 Saving/Loading Conversation

```python
from langgraph.checkpoint.sqlite import SqliteSaver

sqlite = SqliteSaver.from_conn_string("conversations.db")

class PersistentState(TypedDict):
    messages: List[str]

graph = StateGraph(PersistentState)
graph.add_node("process", lambda s: {"messages": s["messages"] + ["processed"]})
graph.set_entry_point("process")
graph.add_edge("process", END)

app = graph.compile(checkpointer=sqlite)

# Save conversation
config = {"configurable": {"thread_id": "session_123"}}
app.invoke({"messages": ["Hello"]}, config=config)
app.invoke({"messages": ["How are you?"]}, config=config)

# Load checkpoint
checkpoint = app.checkpointer.get(config)
print(checkpoint["state"]["messages"])  # ["Hello", "processed", "How are you?", "processed"]
```

### 5.2 Time Travel

```python
# List all checkpoints
checkpoints = list(app.checkpointer.list(config))
for cp in checkpoints:
    print(f"ID: {cp['id']}, Created: {cp['metadata']['created_at']}")

# Replay from checkpoint
replay_config = {
    "configurable": {
        "thread_id": "session_123",
        "checkpoint_id": "checkpoint_abc"
    }
}

for event in app.stream(None, config=replay_config):
    print(event)
```

---

## Branching Examples

### 6.1 Conditional Branching

```python
from typing import TypedDict, Literal
from langgraph.graph import StateGraph, END

class BranchState(TypedDict):
    input: str
    category: str | None
    result: str | None

def categorize(state: BranchState) -> Literal["urgent", "routine", "END"]:
    if "urgent" in state["input"].lower() or "asap" in state["input"].lower():
        return "urgent"
    elif "help" in state["input"].lower() or "question" in state["input"].lower():
        return "routine"
    return "END"

def urgent_handler(state: BranchState) -> BranchState:
    return {"result": "URGENT: " + state["input"]}

def routine_handler(state: BranchState) -> BranchState:
    return {"result": "Routine: " + state["input"]}

graph = StateGraph(BranchState)
graph.add_node("urgent", urgent_handler)
graph.add_node("routine", routine_handler)

graph.set_entry_point("categorize")
graph.add_conditional_edges(
    "categorize",
    categorize,
    {"urgent": "urgent", "routine": "routine", "END": END}
)
graph.add_edge("urgent", END)
graph.add_edge("routine", END)

app = graph.compile()
result = app.invoke({"input": "This is urgent!", "category": None, "result": None})
```

---

## Research-Specific Examples

### 7.1 Paper Analysis Agent

```python
from typing import TypedDict, List
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver
from langchain_core.tools import tool

@tool
def search_arxiv(query: str) -> str:
    """Search arXiv for papers"""
    return f"Results for: {query}"

@tool
def fetch_metadata(paper_id: str) -> dict:
    """Fetch paper metadata"""
    return {"id": paper_id, "title": "Sample Paper", "authors": ["Author A"]}

@tool
def analyze_abstract(abstract: str) -> str:
    """Analyze paper abstract"""
    return "Analysis: This is a good paper about..."

class ResearchState(TypedDict):
    query: str
    papers: List[dict]
    analysis: str | None

def search_node(state: ResearchState) -> ResearchState:
    results = search_arxiv.invoke({"query": state["query"]})
    papers = [{"id": "1234.5678", "title": "Sample Paper"}]
    return {"query": state["query"], "papers": papers, "analysis": None}

def analyze_node(state: ResearchState) -> ResearchState:
    abstract = "Paper abstract here..."
    analysis = analyze_abstract.invoke({"abstract": abstract})
    return {"query": state["query"], "papers": state["papers"], "analysis": analysis}

memory = MemorySaver()
graph = StateGraph(ResearchState)
graph.add_node("search", search_node)
graph.add_node("analyze", analyze_node)

graph.set_entry_point("search")
graph.add_edge("search", "analyze")
graph.add_edge("analyze", END)

app = graph.compile(checkpointer=memory)
result = app.invoke({"query": "transformer architectures", "papers": [], "analysis": None})
```

---

## Complete Production Example

```python
from typing import TypedDict, List, Annotated
from langgraph.graph import StateGraph, END, add_messages
from langgraph.checkpoint.sqlite import SqliteSaver
from langgraph.prebuilt import ToolNode
from langchain_openai import ChatOpenAI
from langchain_core.tools import tool
from langchain_core.messages import SystemMessage, HumanMessage, AIMessage

# Tools
@tool
def search_arxiv(query: str, max_results: int = 5) -> str:
    """Search arXiv for papers"""
    return f"Found {max_results} papers for: {query}"

@tool
def fetch_paper(paper_id: str) -> dict:
    """Fetch paper details"""
    return {"id": paper_id, "title": "Sample Paper", "abstract": "..."}

# State
class ResearchAgentState(TypedDict):
    messages: Annotated[List[HumanMessage | AIMessage], add_messages]
    query: str | None
    papers: List[dict] | None
    intermediate_steps: List[dict]

# Checkpointer
sqlite = SqliteSaver.from_conn_string("research_agent.db")

# LLM
llm = ChatOpenAI(model="gpt-4o")
llm_with_tools = llm.bind_tools([search_arxiv, fetch_paper])

# Nodes
def agent_node(state: ResearchAgentState) -> ResearchAgentState:
    response = llm_with_tools.invoke(state["messages"])
    return {"messages": [response]}

def process_results(state: ResearchAgentState) -> ResearchAgentState:
    last_msg = state["messages"][-1]
    if hasattr(last_msg, "tool_calls") and last_msg.tool_calls:
        papers = []
        for call in last_msg.tool_calls:
            if call["name"] == "fetch_paper":
                paper = fetch_paper.invoke({"paper_id": call["args"]["paper_id"]})
                papers.append(paper)
        return {"papers": papers}
    return {"papers": []}

tool_node = ToolNode([search_arxiv, fetch_paper])

# Graph
graph = StateGraph(ResearchAgentState)
graph.add_node("agent", agent_node)
graph.add_node("tools", tool_node)
graph.add_node("process", process_results)

graph.set_entry_point("agent")
graph.add_conditional_edges(
    "agent",
    lambda s: "tools" if hasattr(s["messages"][-1], "tool_calls") and s["messages"][-1].tool_calls else "process",
    {"tools": "tools", "process": "process"}
)
graph.add_edge("tools", "agent")
graph.add_edge("process", END)

app = graph.compile(checkpointer=sqlite)

# Usage
config = {"configurable": {"thread_id": "user_123"}}
result = app.invoke(
    {"messages": [HumanMessage(content="Find papers on neural networks")]},
    config=config
)
```

---

## Summary

| Category | Examples |
|----------|----------|
| Quick Start | Minimal, basic, cost tracking |
| Tools | Custom, ToolNode, tool calling |
| Streaming | Basic, with events |
| Multi-Turn | Simple, multi-agent |
| Persistence | SQLite, time travel |
| Branching | Conditional routing |
| Research | Paper analysis agent |

---

*Document Version: 1.0*
*Last Updated: January 2026*
