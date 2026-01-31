# LangGraph Tools

## Overview

Tools extend LangGraph agents with the ability to interact with external systems. This document covers tool definition, integration with LangGraph, and best practices.

---

## Tool Definition

### 1.1 Function-Based Tools

```python
from langchain_core.tools import tool

@tool
def search_arxiv(query: str, max_results: int = 5) -> str:
    """Search arXiv for papers matching the query
    
    Args:
        query: Search query for arXiv
        max_results: Maximum number of results to return (default: 5)
    
    Returns:
        Formatted list of matching papers
    """
    import urllib.request
    import urllib.parse
    import xml.etree.ElementTree as ET
    
    base_url = "http://export.arxiv.org/api/query?"
    params = {
        "search_query": f"all:{urllib.parse.quote(query)}",
        "start": 0,
        "max_results": max_results,
        "sortBy": "submittedDate",
        "sortOrder": "descending"
    }
    
    url = base_url + "&".join(f"{k}={v}" for k, v in params.items())
    
    with urllib.request.urlopen(url) as response:
        data = response.read().decode("utf-8")
    
    # Parse ATOM feed
    root = ET.fromstring(data)
    ns = {"atom": "http://www.w3.org/2005/Atom"}
    
    results = []
    for entry in root.findall("atom:entry", ns)[:max_results]:
        title = entry.find("atom:title", ns).text.strip().replace("\n", " ")
        paper_id = entry.find("atom:id", ns).text
        summary = entry.find("atom:summary", ns).text.strip()[:200]
        results.append(f"- {title}\n  ID: {paper_id}\n  {summary}...")
    
    return "\n".join(results) if results else "No papers found."

@tool
def calculate_bmi(weight_kg: float, height_m: float) -> str:
    """Calculate BMI from weight and height
    
    Args:
        weight_kg: Weight in kilograms
        height_m: Height in meters
    
    Returns:
        BMI value and category
    """
    bmi = weight_kg / (height_m ** 2)
    
    if bmi < 18.5:
        category = "Underweight"
    elif bmi < 25:
        category = "Normal"
    elif bmi < 30:
        category = "Overweight"
    else:
        category = "Obese"
    
    return f"BMI: {bmi:.1f} ({category})"
```

### 1.2 Class-Based Tools

```python
from langchain_core.tools import BaseTool
from pydantic import Field

class SearchPapersTool(BaseTool):
    name: str = "search_papers"
    description: str = "Search for academic papers"
    
    max_results: int = Field(default=5, description="Maximum results")
    database: str = Field(default="arxiv", description="Paper database")
    
    def _run(self, query: str) -> str:
        """Execute the search"""
        if self.database == "arxiv":
            return self._search_arxiv(query)
        elif self.database == "semantic_scholar":
            return self._search_semantic_scholar(query)
        return "Unknown database"
    
    def _search_arxiv(self, query: str) -> str:
        """Search arXiv"""
        # Implementation
        return f"arXiv results for: {query}"
    
    def _search_semantic_scholar(self, query: str) -> str:
        """Search Semantic Scholar"""
        # Implementation
        return f"Semantic Scholar results for: {query}"
```

### 1.3 Async Tools

```python
from langchain_core.tools import tool
from typing import List

@tool
async def search_multiple_sources(queries: List[str]) -> List[str]:
    """Search multiple sources concurrently
    
    Args:
        queries: List of search queries
    
    Returns:
        Combined results from all sources
    """
    import asyncio
    import aiohttp
    
    async def search(query: str) -> str:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"https://api.example.com/search?q={query}") as resp:
                return await resp.text()
    
    # Concurrent search
    tasks = [search(q) for q in queries]
    results = await asyncio.gather(*tasks)
    
    return [f"Result for {q}: {r}" for q, r in zip(queries, results)]
```

---

## Tool Integration in LangGraph

### 2.1 Pre-built ToolNode

```python
from typing import TypedDict, List
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode
from langchain_openai import ChatOpenAI

tools = [search_arxiv, calculate_bmi]
tool_node = ToolNode(tools)

class AgentState(TypedDict):
    messages: List[str]
    intermediate_steps: List[dict]

llm = ChatOpenAI(model="gpt-4o")
llm_with_tools = llm.bind_tools(tools)

def agent_node(state: AgentState) -> AgentState:
    """Agent that can use tools"""
    messages = state["messages"]
    response = llm_with_tools.invoke(messages)
    return {"messages": [response], "intermediate_steps": []}

# Build graph
graph = StateGraph(AgentState)
graph.add_node("agent", agent_node)
graph.add_node("tools", tool_node)

graph.set_entry_point("agent")
graph.add_conditional_edges(
    "agent",
    should_continue_agent,
    {
        "continue": "tools",
        "end": END
    }
)
graph.add_edge("tools", "agent")

app = graph.compile()
```

### 2.2 Tool Execution Logic

```python
from langchain_core.messages import ToolMessage, AIMessage

def should_continue_agent(state: AgentState) -> str:
    """Check if agent wants to use tools"""
    messages = state["messages"]
    last_message = messages[-1]
    
    if isinstance(last_message, AIMessage) and last_message.tool_calls:
        return "continue"
    return "end"
```

### 2.3 Custom Tool Integration

```python
from typing import TypedDict, List

class ResearchState(TypedDict):
    query: str
    papers: List[dict]
    search_results: str | None

def search_node(state: ResearchState) -> ResearchState:
    """Custom node that uses search tools"""
    query = state["query"]
    
    # Call tool directly
    result = search_arxiv.invoke({"query": query, "max_results": 10})
    
    return {
        "query": query,
        "papers": [],
        "search_results": result
    }

def analyze_node(state: ResearchState) -> ResearchState:
    """Node that analyzes search results"""
    results = state["search_results"]
    
    # Parse and analyze results
    papers = parse_arxiv_results(results)
    
    return {
        "query": state["query"],
        "papers": papers,
        "search_results": results
    }
```

---

## Built-in Tools

### 3.1 LangChain Built-ins

```python
from langchain_community.tools import (
    TavilySearchResults,
    WikipediaQueryRun,
    ArxivQueryRun,
    DuckDuckGoSearchRun
)
from langchain_community.utilities import (
    WikipediaAPIWrapper,
    ArxivAPIWrapper
)

# Web search
web_search = TavilySearchResults(max_results=5)

# Wikipedia
wikipedia = WikipediaQueryRun(api_wrapper=WikipediaAPIWrapper())

# arXiv
arxiv_search = ArxivQueryRun(api_wrapper=ArxivAPIWrapper())

# DuckDuckGo
duckduckgo = DuckDuckGoSearchRun()
```

### 3.2 File Operations

```python
from langchain_community.agent_toolkits import FileManagementToolkit

file_tools = FileManagementToolkit(
    root_dir="/workspace",
    allowed_tools=["read_file", "write_file", "list_dir", "glob"]
).get_tools()

# Use in graph
tool_node = ToolNode(file_tools)
```

### 3.3 Database Tools

```python
from langchain_community.tools import (
    QuerySQLDatabaseTool,
    ListSQLDatabaseTool
)

# SQL Database
sql_query = QuerySQLDatabaseTool(db=my_database)
sql_list = ListSQLDatabaseTool(db=my_database)

# Neo4j
from langchain_community.graphs import Neo4jGraph
neo4j_query = """MATCH (p:Paper)-[:CITES]->(c:Paper)
                 WHERE p.id = $paper_id
                 RETURN c"""

# PostgreSQL with pgvector
from langchain_community.vectorstores import PGVector
vector_search = PGVector(...)
```

---

## Tool Error Handling

### 4.1 Structured Error Handling

```python
from langchain_core.tools import tool
from pydantic import ValidationError

@tool
def safe_search(query: str) -> str:
    """Search with error handling"""
    try:
        result = external_search(query)
        return result
    except ValidationError as e:
        return f"Validation error: {str(e)}"
    except ConnectionError as e:
        return f"Connection error: {str(e)}"
    except Exception as e:
        return f"Unexpected error: {str(e)}"
```

### 4.2 Retry Logic

```python
from tenacity import retry, stop_after_attempt, wait_exponential

@tool
@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=10))
def resilient_search(query: str) -> str:
    """Search with automatic retry"""
    result = external_api_search(query)
    return result
```

---

## Custom Tool Creation for Agents

### 6.1 Custom Tool Patterns

#### Agent-Specific Tools

```python
from typing import Dict, Any, Optional
from langchain_core.tools import Tool

class AgentToolResult:
    def __init__(self, success: bool, result: Any, error: Optional[str] = None):
        self.success = success
        self.result = result
        self.error = error


def create_agent_tool(name: str, func, description: str) -> Tool:
    """Create a LangGraph-compatible tool for agents."""
    return Tool(
        name=name,
        func=func,
        description=description,
        return_type="agent_tool_result"
    )


def research_tool(
    state: Dict[str, Any],
    input_data: Dict[str, Any]
) -> AgentToolResult:
    """Research paper analysis tool for academic agents."""
    try:
        paper_id = input_data.get('paper_id')
        analysis_type = input_data.get('type', 'basic')
        
        # Validate input
        if not paper_id:
            return AgentToolResult(False, None, "Paper ID is required")
        
        # Agent-specific logic
        if analysis_type == 'basic':
            result = analyze_paper_basic(paper_id)
        elif analysis_type == 'deep':
            result = analyze_paper_deep(paper_id, state.get('user_context'))
        else:
            return AgentToolResult(False, None, f"Unknown analysis type: {analysis_type}")
        
        return AgentToolResult(True, result)
    except Exception as e:
        return AgentToolResult(False, None, f"Research tool error: {str(e)}")
```

#### Multi-Agent Tools

```python
def multi_agent_tool(
    state: Dict[str, Any],
    input_data: Dict[str, Any]
) -> AgentToolResult:
    """Tool that coordinates multiple agents."""
    try:
        task_type = input_data.get('task')
        task_data = input_data.get('data')
        
        if task_type == 'complex_analysis':
            # Route to specialized agents
            result = coordinate_complex_analysis(state, task_data)
        elif task_type == 'data_processing':
            result = coordinate_data_processing(state, task_data)
        else:
            return AgentToolResult(False, None, f"Unknown task type: {task_type}")
        
        return AgentToolResult(True, result)
    except Exception as e:
        return AgentToolResult(False, None, f"Multi-agent tool error: {str(e)}")
```

#### State-Aware Tools

```python
def state_aware_tool(
    state: Dict[str, Any],
    input_data: Dict[str, Any]
) -> AgentToolResult:
    """Tool that leverages agent state."""
    try:
        user_id = state.get('user_id')
        session_data = state.get('session_data', {})
        
        # Context-aware operations
        if user_id and user_id in session_data:
            context = session_data[user_id]
            result = perform_context_aware_operation(input_data, context)
        else:
            result = perform_default_operation(input_data)
        
        return AgentToolResult(True, result)
    except Exception as e:
        return AgentToolResult(False, None, f"State-aware tool error: {str(e)}")
```

### 6.2 Tool Integration Patterns

#### Agent Node Integration

```python
from typing import TypedDict, List
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode

class AgentState(TypedDict):
    messages: List[str]
    tools_used: List[str]
    session_context: Dict[str, Any]


def agent_node_with_tools(state: AgentState) -> AgentState:
    """Agent node that can use custom tools."""
    messages = state["messages"]
    
    # Create tools specific to this agent
    tools = [
        create_agent_tool(
            "research_analyzer",
            research_tool,
            "Analyze research papers with context awareness"
        ),
        create_agent_tool(
            "multi_agent_coordinator",
            multi_agent_tool,
            "Coordinate multiple specialized agents"
        )
    ]
    
    # Bind tools to LLM
    llm_with_tools = llm.bind_tools(tools)
    response = llm_with_tools.invoke(messages)
    
    # Track tool usage
    tools_used = [call.name for call in response.tool_calls] if hasattr(response, 'tool_calls') else []
    
    return {
        "messages": [response],
        "tools_used": tools_used,
        "session_context": state.get("session_context", {})
    }
```

#### Tool Selection Logic

```python
def tool_selection_logic(state: AgentState) -> str:
    """Determine which tool to use based on context."""
    messages = state["messages"]
    last_message = messages[-1] if messages else ""
    
    if "analyze paper" in last_message.lower():
        return "research_analyzer"
    elif "coordinate agents" in last_message.lower():
        return "multi_agent_coordinator"
    elif "context-aware" in last_message.lower():
        return "state_aware_tool"
    return "default_tool"
```

### 6.3 Custom Tool Examples

#### Research Agent Tools

```python
def citation_analysis_tool(
    state: Dict[str, Any],
    input_data: Dict[str, Any]
) -> AgentToolResult:
    """Analyze paper citations and impact."""
    try:
        paper_id = input_data.get('paper_id')
        depth = input_data.get('depth', '1')
        
        # Citation analysis logic
        citations = get_paper_citations(paper_id)
        impact_score = calculate_impact_score(citations, depth)
        
        return AgentToolResult(True, {
            'citations': citations,
            'impact_score': impact_score,
            'recommendation': generate_recommendation(citations, impact_score)
        })
    except Exception as e:
        return AgentToolResult(False, None, f"Citation analysis failed: {str(e)}")
```

#### Data Processing Agent Tools

```python
def data_pipeline_tool(
    state: Dict[str, Any],
    input_data: Dict[str, Any]
) -> AgentToolResult:
    """Process data through pipeline stages."""
    try:
        pipeline_stage = input_data.get('stage')
        data = input_data.get('data')
        
        if pipeline_stage == 'ingest':
            processed = ingest_data(data)
        elif pipeline_stage == 'transform':
            processed = transform_data(data, state.get('transform_config'))
        elif pipeline_stage == 'validate':
            processed = validate_data(data)
        else:
            return AgentToolResult(False, None, f"Unknown pipeline stage: {pipeline_stage}")
        
        return AgentToolResult(True, processed)
    except Exception as e:
        return AgentToolResult(False, None, f"Data pipeline error: {str(e)}")
```

### 6.4 Tool Composition

#### Composite Tools

```python
def composite_tool(
    state: Dict[str, Any],
    input_data: Dict[str, Any]
) -> AgentToolResult:
    """Composite tool that combines multiple operations."""
    try:
        operations = input_data.get('operations', [])
        results = {}
        
        for operation in operations:
            op_type = operation.get('type')
            op_data = operation.get('data')
            
            if op_type == 'research':
                result = research_tool(state, op_data)
            elif op_type == 'analysis':
                result = citation_analysis_tool(state, op_data)
            else:
                result = AgentToolResult(False, None, f"Unknown operation: {op_type}")
            
            results[op_type] = result
        
        return AgentToolResult(True, results)
    except Exception as e:
        return AgentToolResult(False, None, f"Composite tool error: {str(e)}")
```

#### Tool Chaining

```python
def chained_tools(
    state: Dict[str, Any],
    input_data: Dict[str, Any]
) -> AgentToolResult:
    """Chain multiple tools together."""
    try:
        initial_data = input_data.get('initial_data')
        
        # Stage 1: Research
        research_result = research_tool(state, {"paper_id": initial_data["paper_id"]})
        if not research_result.success:
            return research_result
        
        # Stage 2: Analysis
        analysis_data = {"paper_id": initial_data["paper_id"], "citations": research_result.result["citations"]}
        analysis_result = citation_analysis_tool(state, analysis_data)
        
        return AgentToolResult(True, {
            'research': research_result.result,
            'analysis': analysis_result.result
        })
    except Exception as e:
        return AgentToolResult(False, None, f"Tool chain error: {str(e)}")
```

### 6.5 Tool Testing

#### Unit Testing Custom Tools

```python
import unittest
from unittest.mock import patch, MagicMock

class TestCustomTools(unittest.TestCase):
    
    def test_research_tool_success(self):
        state = {"user_context": {"preferences": {"field": "AI"}}}
        input_data = {"paper_id": "2101.00123", "type": "deep"}
        
        with patch('analyze_paper_deep') as mock_analysis:
            mock_analysis.return_value = {"result": "deep analysis"}
            result = research_tool(state, input_data)
            
            self.assertTrue(result.success)
            self.assertEqual(result.result, {"result": "deep analysis"})
    
    def test_citation_analysis_tool_failure(self):
        state = {}
        input_data = {"paper_id": "", "depth": "1"}
        
        result = citation_analysis_tool(state, input_data)
        
        self.assertFalse(result.success)
        self.assertIn("Paper ID is required", result.error)
```

#### Integration Testing

```python
def test_tool_integration(graph: StateGraph):
    """Test custom tools within LangGraph."""
    # Initialize state
    initial_state = {
        "user_context": {"research_field": "machine_learning"},
        "session_data": {"user_123": {"preferences": {"depth": "detailed"}}}
    }
    
    # Test research tool
    tool_input = {"paper_id": "2101.00123", "type": "deep"}
    result = research_tool(initial_state, tool_input)
    
    assert result.success
    assert "result" in result.result
    
    # Test citation analysis
    citation_input = {"paper_id": "2101.00123", "depth": "2"}
    citation_result = citation_analysis_tool(initial_state, citation_input)
    
    assert citation_result.success
    assert "citations" in citation_result.result
```

### 6.6 Performance Considerations

#### Caching Strategy

```python
from functools import lru_cache

@lru_cache(maxsize=128)
def cached_research_tool(
    state: Dict[str, Any],
    input_data: Dict[str, Any]
) -> AgentToolResult:
    """Cached research tool for better performance."""
    try:
        # Use a hash of input_data for caching
        cache_key = hash(frozenset(input_data.items()))
        
        # Tool logic here
        result = perform_research(input_data["paper_id"])
        
        return AgentToolResult(True, result)
    except Exception as e:
        return AgentToolResult(False, None, f"Cached tool error: {str(e)}")
```

#### Async Tools

```python
import asyncio

def async_research_tool(
    state: Dict[str, Any],
    input_data: Dict[str, Any]
) -> AgentToolResult:
    """Async research tool for concurrent operations."""
    try:
        loop = asyncio.get_event_loop()
        result = loop.run_until_complete(
            perform_async_research(input_data["paper_id"])
        )
        return AgentToolResult(True, result)
    except Exception as e:
        return AgentToolResult(False, None, f"Async tool error: {str(e)}")
```

---

## Best Practices

### 7.1 Tool Design

1. **Clear Descriptions**
    ```python
    @tool
    def analyze_paper(paper_id: str, depth: str = "shallow") -> dict:
        """Analyze an academic paper by ID
        
        Args:
            paper_id: The unique identifier for the paper (arXiv ID or DOI)
            depth: Analysis depth - 'shallow' (basic info) or 'deep' (full text)
        
        Returns:
            Dictionary containing paper analysis
        """
    ```

2. **Proper Type Hints**
    ```python
    @tool
    def search_papers(
        query: str,
        filters: dict | None = None,
        max_results: int = 10
    ) -> List[dict]:
        """Search with proper type annotations"""
    ```

3. **Error Messages**
    ```python
    @tool
    def fetch_paper(paper_id: str) -> str:
        """Fetch paper details"
        if not paper_id:
            return "Error: Paper ID is required"
        # ...
    ```

### 7.2 Tool Organization

```python
# tools/__init__.py
tools/__init__.py
from .research import research_tool, citation_analysis_tool
from .data import data_pipeline_tool, data_processing_tool
from .coordination import multi_agent_tool, composite_tool

__all__ = [
    "research_tool",
    "citation_analysis_tool",
    "data_pipeline_tool",
    "data_processing_tool",
    "multi_agent_tool",
    "composite_tool",
]
```

### 7.3 Tool Versioning

```python
def versioned_tool(
    state: Dict[str, Any],
    input_data: Dict[str, Any]
) -> AgentToolResult:
    """Tool with versioning support."""
    try:
        tool_version = state.get('tool_version', '1.0')
        
        if tool_version == '1.0':
            result = legacy_tool_logic(input_data)
        elif tool_version == '1.1':
            result = improved_tool_logic(input_data)
        else:
            return AgentToolResult(False, None, f"Unknown tool version: {tool_version}")
        
        return AgentToolResult(True, result)
    except Exception as e:
        return AgentToolResult(False, None, f"Versioned tool error: {str(e)}")
```

---

## Summary

Custom tools for agents extend LangGraph's capabilities by:

- **Agent-Specific Tools**: Tools tailored for specific agent types and use cases
- **Multi-Agent Coordination**: Tools that manage and coordinate multiple agents
- **State-Aware Operations**: Tools that leverage agent state for context-aware decisions
- **Tool Composition**: Combining multiple tools for complex operations
- **Performance Optimization**: Caching and async patterns for better performance

For more information, see the [LangGraph Tools Guide](tools.md) and [LangGraph API Reference](api.md).
   ```python
   @tool
   def analyze_paper(paper_id: str, depth: str = "shallow") -> dict:
       """Analyze an academic paper by ID
       
       Args:
           paper_id: The unique identifier for the paper (arXiv ID or DOI)
           depth: Analysis depth - 'shallow' (basic info) or 'deep' (full text)
       
       Returns:
           Dictionary containing paper analysis
       """
   ```

2. **Proper Type Hints**
   ```python
   @tool
   def search_papers(
       query: str,
       filters: dict | None = None,
       max_results: int = 10
   ) -> List[dict]:
       """Search with proper type annotations"""
   ```

3. **Error Messages**
   ```python
   @tool
   def fetch_paper(paper_id: str) -> str:
       """Fetch paper details"""
       if not paper_id:
           return "Error: Paper ID is required"
       # ...
   ```

### 5.2 Tool Organization

```python
# tools/__init__.py
from .search import search_arxiv, search_semantic_scholar
from .analysis import analyze_paper, calculate_metrics
from .database import query_postgres, query_neo4j
from .file import read_file, write_file, list_directory

__all__ = [
    "search_arxiv",
    "search_semantic_scholar",
    "analyze_paper",
    "calculate_metrics",
    "query_postgres",
    "query_neo4j",
    "read_file",
    "write_file",
    "list_directory",
]
```

---

## Summary

| Feature | Description |
|---------|-------------|
| @tool Decorator | Create tools from functions |
| BaseTool Class | Custom class-based tools |
| Async Tools | Concurrent tool execution |
| ToolNode | Pre-built node for tool execution |
| Built-in Tools | LangChain community tools |
| Error Handling | Structured error management |

---

*Document Version: 1.0*
*Last Updated: January 2026*
