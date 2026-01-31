# LangGraph with LangChain Integration Patterns

This guide covers various patterns and best practices for integrating LangGraph with LangChain to build powerful agentic applications.

## Overview

LangGraph provides the orchestration layer for building stateful, multi-step workflows, while LangChain offers a rich ecosystem of tools, models, and components for language AI applications. Together, they enable sophisticated agent architectures.

## Core Integration Patterns

### 1. LangChain Tools in LangGraph Nodes

The most common integration pattern is using LangChain tools within LangGraph nodes for specific tasks.

```python
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI
from langchain_community.tools import ArxivAPI

class ResearchState(TypedDict):
    query: str
    papers: list
    result: str | None

llm = ChatOpenAI(model="gpt-4o")
arxiv_tool = ArxivAPI()

def search_node(state: ResearchState):
    """Use LangChain tool within LangGraph node"""
    papers = arxiv_tool.run(state["query"])
    return {"papers": papers}

def analyze_node(state: ResearchState):
    """Use LangChain LLM within LangGraph node"""
    analysis = llm.invoke(
        f"Analyze these research papers: {state['papers']}"
    )
    return {"analysis": analysis}

graph = StateGraph(ResearchState)
graph.add_node("search", search_node)
graph.add_node("analyze", analyze_node)
graph.set_entry_point("search")
graph.add_edge("search", "analyze")
graph.add_edge("analyze", END)
```

### 2. LangChain Chains as LangGraph Subgraphs

Complex LangChain chains can be encapsulated as LangGraph subgraphs for better orchestration.

```python
from langgraph.graph import StateGraph, END
from langchain.chains import RetrievalQA
from langchain_community.document_loaders import ArxivLoader
from langchain_community.embeddings import OpenAIEmbeddings

class QASubgraphState(TypedDict):
    query: str
    context: str | None
    answer: str | None

embeddings = OpenAIEmbeddings()
loader = ArxivLoader()
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    chain_type="stuff",
    retriever=loader.create_retriever(embeddings=embeddings)
)

def query_node(state: QASubgraphState):
    """Query LangChain chain"""
    context = qa_chain.run(state["query"])
    return {"context": context}

def answer_node(state: QASubgraphState):
    """Generate answer"""
    answer = llm.invoke(f"Based on this context, answer: {state['query']}")
    return {"answer": answer}

subgraph = StateGraph(QASubgraphState)
subgraph.add_node("query", query_node)
subgraph.add_node("answer", answer_node)
subgraph.set_entry_point("query")
subgraph.add_edge("query", "answer")
subgraph.add_edge("answer", END)
```

## Advanced Integration Patterns

### 3. Agent-Based Integration

Use LangChain agents within LangGraph for dynamic tool selection.

```python
from langgraph.graph import StateGraph, END
from langchain.agents import create_openai_tools_agent, AgentExecutor
from langchain.tools import Tool

class AgentState(TypedDict):
    query: str
    tools_used: list
    result: str | None

llm = ChatOpenAI(model="gpt-4o")
tools = [
    Tool(name="ArxivSearch", func=search_arxiv, description="Search Arxiv papers"),
    Tool(name="Summarize", func=summarize_paper, description="Summarize research papers")
]
agent = create_openai_tools_agent(llm, tools, "Arxiv Researcher")
agent_executor = AgentExecutor(agent=agent, tools=tools)

def agent_node(state: AgentState):
    """Use LangChain agent for dynamic tool selection"""
    result = agent_executor.invoke(state["query"])
    tools_used = agent_executor.agent.tools_used
    return {"result": result, "tools_used": tools_used}

graph = StateGraph(AgentState)
graph.add_node("agent", agent_node)
graph.set_entry_point("agent")
graph.add_edge("agent", END)
```

### 4. Memory Integration

Combine LangGraph state with LangChain memory for persistent conversation context.

```python
from langgraph.graph import StateGraph, END
from langchain.memory import ConversationBufferMemory
from langchain_openai import ChatOpenAI

class MemoryState(TypedDict):
    query: str
    conversation_history: list
    result: str | None

memory = ConversationBufferMemory()
llm = ChatOpenAI(model="gpt-4o")

def memory_node(state: MemoryState):
    """Use LangChain memory with LangGraph state"""
    memory.add_user_message(state["query"])
    conversation_history = memory.buffer
    result = llm.invoke(f"Continue conversation: {conversation_history}")
    return {"conversation_history": conversation_history, "result": result}

graph = StateGraph(MemoryState)
graph.add_node("memory", memory_node)
graph.set_entry_point("memory")
graph.add_edge("memory", END)
```

## Best Practices

### 1. State Management

- Use LangGraph state for persistent data across nodes
- Use LangChain components for transient processing
- Keep state serializable for persistence

```python
class IntegratedState(TypedDict):
    # LangGraph state
    user_query: str
    papers: list
    analysis: str | None
    
    # LangChain component state
    memory_buffer: str | None
    agent_tools_used: list | None
```

### 2. Error Handling

- LangGraph handles node-level errors
- LangChain handles tool/LLM errors
- Combine for comprehensive error handling

```python
def robust_node(state: AgentState):
    try:
        # Use LangChain tool
        result = arxiv_tool.run(state["query"])
        return {"result": result}
    except Exception as e:
        # Handle LangChain errors
        error_message = f"Tool error: {str(e)}"
        return {"error": error_message, "retry": True}
```

### 3. Performance Optimization

- Cache LangChain components when possible
- Use streaming for long-running operations
- Batch operations when appropriate

```python
# Cache LangChain components
@cache
def get_cached_qa_chain():
    return RetrievalQA.from_chain_type(
        llm=llm,
        chain_type="stuff",
        retriever=arxiv_retriever
    )
```

## Common Use Cases

### 1. Research Assistant

Combine Arxiv search, paper analysis, and summarization.

```python
class ResearchAssistantState(TypedDict):
    query: str
    papers: list
    summaries: list
    insights: str | None

# Nodes:
# 1. Search papers (LangChain tool)
# 2. Analyze papers (LangChain LLM)
# 3. Generate insights (LangGraph orchestration)
```

### 2. Document Q&A System

Use LangChain retrieval with LangGraph workflow control.

```python
class QAMachineState(TypedDict):
    question: str
    documents: list
    context: str | None
    answer: str | None

# Nodes:
# 1. Load documents (LangChain loader)
# 2. Retrieve context (LangChain retriever)
# 3. Generate answer (LangChain LLM)
# 4. Format response (LangGraph formatting)
```

### 3. Multi-Modal Agent

Combine text, image, and code processing.

```python
class MultiModalState(TypedDict):
    input: str | None
    image: str | None
    code: str | None
    analysis: str | None

# Nodes:
# 1. Process text (LangChain LLM)
# 2. Analyze image (LangChain vision)
# 3. Execute code (LangChain code)
# 4. Synthesize results (LangGraph)
```

## Integration with Other Components

### 1. LangGraph + LangChain + Ollama

Use Ollama as the LLM backend for both systems.

```python
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI
from langchain_community.ollama import Ollama

class OllamaState(TypedDict):
    query: str
    response: str | None

# Use Ollama for both LangGraph and LangChain
llm = ChatOpenAI(model=Ollama(model="llama3"))

def ollama_node(state: OllamaState):
    response = llm.invoke(state["query"])
    return {"response": response}
```

### 2. LangGraph + LangChain + PostgreSQL

Store conversation history and results in PostgreSQL.

```python
class DatabaseState(TypedDict):
    query: str
    papers: list
    analysis: str | None
    postgres_client: object | None

# Use LangChain for processing, PostgreSQL for storage

def store_results_node(state: DatabaseState):
    # Use LangChain for formatting
    formatted = llm.invoke(f"Format these results: {state['papers']}")
    
    # Store in PostgreSQL using LangGraph state
    state["postgres_client"].execute(
        "INSERT INTO results (query, formatted) VALUES (%s, %s)",
        (state["query"], formatted)
    )
    return {}
```

## Migration Patterns

### From LangChain to LangGraph

1. **Identify workflow steps** - Break LangChain chains into discrete nodes
2. **Extract state** - Determine what data needs to persist
3. **Add error handling** - Implement LangGraph error patterns
4. **Add observability** - Track node execution and state changes

### From LangGraph to LangChain

1. **Identify tool usage** - Replace LangGraph nodes with LangChain tools
2. **Extract processing logic** - Move to LangChain components
3. **Simplify orchestration** - Use LangChain's built-in chaining
4. **Maintain state** - Use LangChain memory for conversation context

## Troubleshooting

### Common Issues

1. **State serialization** - Ensure all state is JSON serializable
2. **Memory leaks** - LangChain components may hold references
3. **Performance bottlenecks** - LangChain operations can be slow
4. **Error propagation** - Handle both LangGraph and LangChain errors

### Debugging Tips

- Use LangGraph's built-in logging
- Monitor LangChain component performance
- Test nodes independently
- Use the LangChain debug mode

## Conclusion

Integrating LangGraph with LangChain provides a powerful combination for building sophisticated agentic applications. LangGraph provides the orchestration and state management, while LangChain offers rich tools and components for AI processing.

By following these patterns and best practices, you can build robust, scalable applications that leverage the strengths of both frameworks.

Remember to:
- Keep state management clear and consistent
- Handle errors appropriately at both levels
- Optimize for performance and resource usage
- Test thoroughly with real-world scenarios