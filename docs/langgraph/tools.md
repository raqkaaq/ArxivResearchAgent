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

## Best Practices

### 5.1 Tool Design

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
