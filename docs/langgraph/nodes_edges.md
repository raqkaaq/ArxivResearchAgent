# Node and Edge Types Guide

This guide provides a comprehensive overview of node and edge types in LangGraph, covering all available node types, edge configurations, and best practices for building robust graph-based agent systems.

## Overview

In LangGraph, nodes represent discrete processing steps and edges define the flow between these steps. Understanding the different types of nodes and how to configure edges is crucial for building effective agent architectures.

---

## Nodes

### 1.1 Basic Node Structure

```python
from typing import TypedDict

class AgentState(TypedDict):
    input: str
    output: str | None

def my_node(state: AgentState) -> AgentState:
    """A basic node that processes state"""
    # Access state
    input_text = state["input"]
    
    # Do processing
    result = process(input_text)
    
    # Return updated state
    return {"output": result}
```

### 1.2 Node Types

#### LLM Nodes

```python
from typing import TypedDict, List
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(model="gpt-4o")

class ConversationState(TypedDict):
    messages: List[str]

def llm_node(state: ConversationState) -> ConversationState:
    """Node that calls an LLM"""
    messages = [SystemMessage(content="You are a helpful assistant.")]
    messages.extend([HumanMessage(content=m) for m in state["messages"]])
    
    response = llm.invoke(messages)
    
    return {"messages": state["messages"] + [response.content]}
```

#### Tool Nodes

```python
from typing import TypedDict
from langchain_core.tools import tool

@tool
def search_arxiv(query: str) -> str:
    """Search arXiv for papers"""
    # Implementation
    return "results"

@tool
def analyze_paper(paper_id: str) -> dict:
    """Analyze a paper"""
    # Implementation
    return {"title": "...", "summary": "..."}

class ResearchState(TypedDict):
    query: str
    papers: List[dict]
    results: List[str]

def tool_node(state: ResearchState) -> ResearchState:
    """Node that uses tools"""
    papers = []
    for query in [state["query"]]:
        result = search_arxiv(query)
        papers.append(result)
    
    return {"papers": papers, "results": []}
```

#### Data Nodes

```python
from typing import TypedDict

class DataState(TypedDict):
    raw_data: str
    processed_data: str | None
    analysis: dict | None

def load_data(state: DataState) -> DataState:
    """Load data from external source"""
    import requests
    response = requests.get(state["raw_data"])
    return {"processed_data": response.text}

def process_data(state: DataState) -> DataState:
    """Process loaded data"""
    data = state["processed_data"]
    # Do processing
    return {"analysis": {"length": len(data)}}
```

#### Action Nodes

```python
from typing import TypedDict

class ActionState(TypedDict):
    command: str
    result: str | None

def execute_command(state: ActionState) -> ActionState:
    """Execute a shell command"""
    import subprocess
    result = subprocess.run(
        state["command"],
        shell=True,
        capture_output=True,
        text=True
    )
    return {"result": result.stdout or result.stderr}
```

### 1.3 Node Parameters

```python
from typing import TypedDict, Callable

class NodeState(TypedDict):
    value: int

# Nodes can accept additional parameters via partial
from functools import partial

def configurable_node(state: NodeState, multiplier: int = 1) -> NodeState:
    """Node with configurable parameters"""
    return {"value": state["value"] * multiplier}

# Create node with specific multiplier
double_node = partial(configurable_node, multiplier=2)
triple_node = partial(configurable_node, multiplier=3)

graph.add_node("double", double_node)
graph.add_node("triple", triple_node)
```

---

## Edges

### 2.1 Direct Edges

```python
from langgraph.graph import StateGraph, END, START

graph = StateGraph(AgentState)

# Add nodes
graph.add_node("process", process_node)
graph.add_node("analyze", analyze_node)
graph.add_node("respond", respond_node)

# Set entry point
graph.set_entry_point("process")

# Direct edges
graph.add_edge("process", "analyze")
graph.add_edge("analyze", "respond")
graph.add_edge("respond", END)
```

### 2.2 Conditional Edges

```python
from typing import TypedDict, Literal

class RoutingState(TypedDict):
    input: str
    decision: str | None
    result: str | None

def should_continue(state: RoutingState) -> Literal["continue", "end"]:
    """Determine next step"""
    if state["result"] and len(state["result"]) > 100:
        return "continue"
    return "end"

# Add conditional edge
graph.add_conditional_edges(
    "analyze",
    should_continue,
    {
        "continue": "respond",
        "end": END
    }
)
```

### 2.3 Multiple Routing

```python
from typing import TypedDict, Literal

class MultiRouteState(TypedDict):
    input: str
    category: str | None
    result: str | None

def categorize(state: MultiRouteState) -> Literal["research", "coding", "general", "END"]:
    """Route to appropriate handler"""
    input_lower = state["input"].lower()
    
    if "paper" in input_lower or "research" in input_lower:
        return "research"
    elif "code" in input_lower or "implement" in input_lower:
        return "coding"
    elif "exit" in input_lower or "quit" in input_lower:
        return "END"
    return "general"

graph.add_conditional_edges(
    "categorize",
    categorize,
    {
        "research": "research_node",
        "coding": "coding_node",
        "general": "respond",
        "END": END
    }
)
```

### 2.4 Fan-Out/Fan-In Patterns

```python
from typing import TypedDict, List
from concurrent.futures import ThreadPoolExecutor

class ParallelState(TypedDict):
    items: List[str]
    results: List[str]

def fan_out(state: ParallelState) -> ParallelState:
    """Fan out to process items in parallel"""
    with ThreadPoolExecutor(max_workers=4) as executor:
        results = list(executor.map(process_item, state["items"]))
    return {"results": results}

def process_item(item: str) -> str:
    """Process a single item"""
    return f"processed: {item}"

graph.add_node("parallel_process", fan_out)
graph.add_edge("parallel_process", END)
```

---

## Graph Construction

### 3.1 Basic Graph

```python
from langgraph.graph import StateGraph, END, START

graph = StateGraph(AgentState)

# Add nodes
graph.add_node("start", start_node)
graph.add_node("process", process_node)
graph.add_node("end", end_node)

# Define flow
graph.set_entry_point("start")
graph.add_edge("start", "process")
graph.add_edge("process", "end")
graph.add_edge("end", END)

# Compile
app = graph.compile()
```

### 3.2 Graph with Branches

```python
from typing import TypedDict, Literal

class BranchState(TypedDict):
    input: str
    branch_a_result: str | None
    branch_b_result: str | None
    final_result: str | None

def branch_a(state: BranchState) -> BranchState:
    return {"branch_a_result": f"A: {state['input']}"}

def branch_b(state: BranchState) -> BranchState:
    return {"branch_b_result": f"B: {state['input']}"}

def merge_results(state: BranchState) -> BranchState:
    return {
        "final_result": f"{state['branch_a_result']} | {state['branch_b_result']}"
    }

# Build graph with branches
graph = StateGraph(BranchState)
graph.add_node("branch_a", branch_a)
graph.add_node("branch_b", branch_b)
graph.add_node("merge", merge_results)

graph.set_entry_point("branch_a")
graph.add_edge("branch_a", "branch_b")
graph.add_edge("branch_b", "merge")
graph.add_edge("merge", END)
```

### 3.3 Graph with Cycles

```python
from typing import TypedDict, Literal

class CyclicState(TypedDict):
    iteration: int
    max_iterations: int
    result: str | None

def process_cyclically(state: CyclicState) -> CyclicState:
    """Process that may need multiple iterations"""
    if state["iteration"] >= state["max_iterations"]:
        return {"result": "max iterations reached"}
    
    # Do work
    return {"iteration": state["iteration"] + 1}

def should_continue(state: CyclicState) -> Literal["continue", "end"]:
    """Check if we should continue"""
    if state["result"]:
        return "end"
    if state["iteration"] >= state["max_iterations"]:
        return "end"
    return "continue"

graph = StateGraph(CyclicState)
graph.add_node("process", process_cyclically)

graph.set_entry_point("process")
graph.add_conditional_edges(
    "process",
    should_continue,
    {
        "continue": "process",
        "end": END
    }
)
```

---

## State Schema

### 4.1 Schema Requirements

Nodes must have consistent input/output schemas:

```python
from typing import TypedDict

# All nodes must accept and return this state
class AgentState(TypedDict):
    input: str
    output: str | None
    metadata: dict | None

# Node 1: Accepts full state, returns partial
def node_1(state: AgentState) -> AgentState:
    return {"output": f"processed: {state['input']}"}

# Node 2: Also accepts full state
def node_2(state: AgentState) -> AgentState:
    return {"metadata": {"node": "2"}}
```

### 4.2 Optional Fields

```python
from typing import TypedDict, NotRequired

class OptionalState(TypedDict):
    required_field: str
    optional_field: NotRequired[str]

def node_with_optional(state: OptionalState) -> OptionalState:
    # Can return or omit optional fields
    if some_condition:
        return {"required_field": state["required_field"], "optional_field": "value"}
    return {"required_field": state["required_field"]}
```

---

## Error Handling

### 5.1 Try/Catch in Nodes

```python
from typing import TypedDict

class SafeState(TypedDict):
    input: str
    result: str | None
    error: str | None

def safe_node(state: SafeState) -> SafeState:
    """Node with error handling"""
    try:
        result = risky_operation(state["input"])
        return {"result": result, "error": None}
    except Exception as e:
        return {"result": None, "error": str(e)}

def error_handler(state: SafeState) -> SafeState:
    """Handle errors from previous node"""
    if state["error"]:
        return {"result": f"Recovered from: {state['error']}"}
    return {"result": state["result"]}
```

### 5.2 Retry with Checkpoint

```python
def retry_node(state: AgentState) -> AgentState:
    """Node that can be retried"""
    try:
        result = unreliable_operation(state["input"])
        return {"result": result}
    except Exception as e:
        # On failure, state is checkpointed
        # Next retry will pick up from here
        raise

# Use with interrupt for manual retry
app = graph.compile(
    checkpointer=memory,
    interrupt_before=["retry_node"]
)
```

---

## Best Practices

### 6.1 Node Granularity

```python
# Good: Single responsibility
def search_node(state: SearchState) -> SearchState:
    return {"results": search(state["query"])}

def filter_node(state: FilterState) -> FilterState:
    return {"filtered": filter_results(state["results"], state["criteria"])}

def rank_node(state: RankState) -> RankState:
    return {"ranked": rank(state["filtered"])}

# Bad: Too much in one node
def everything_node(state: State) -> State:
    results = search(state["query"])
    filtered = filter(results, state["criteria"])
    ranked = rank(filtered)
    return {"ranked": ranked}
```

### 6.2 Clear State Flow

```python
# State is explicit and clear
class ProcessingState(TypedDict):
    raw_input: str
    cleaned_input: str | None
    analysis: dict | None
    output: str | None

def clean(state: ProcessingState) -> ProcessingState:
    return {"cleaned_input": clean_text(state["raw_input"])}

def analyze(state: ProcessingState) -> ProcessingState:
    return {"analysis": analyze_text(state["cleaned_input"])}

def format_output(state: ProcessingState) -> ProcessingState:
    return {"output": format_results(state["analysis"])}
```

### 6.3 Idempotent Nodes

```python
def idempotent_node(state: AgentState) -> AgentState:
    """Node that can be safely re-run"""
    # Use current state, not assumed previous state
    if state.get("result"):
        return {"result": state["result"]}  # Already processed
    
    return {"result": process(state["input"])}
```

---

## Summary

| Component | Description |
|-----------|-------------|
| Nodes | Python functions that transform state |
| Direct Edges | Fixed flow between nodes |
| Conditional Edges | Dynamic routing based on state |
| State Schema | TypedDict defining state structure |
| Cycles | For iterative agent behavior |
| Fan-Out/Fan-In | Parallel processing patterns |

---

*Document Version: 1.0*
*Last Updated: January 2026*
