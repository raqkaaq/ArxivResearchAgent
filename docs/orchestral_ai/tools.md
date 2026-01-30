# Orchestral AI Tools

## Overview

Orchestral AI provides a **type-safe tool framework** with automatic schema generation from Python type hints. Tools extend the agent's capabilities beyond text generation to include file operations, code execution, web search, and more.

**Source: Orchestral AI Documentation and arXiv Paper 2601.02577**

---

## Tool Definition

### 1.1 Function-Based Definition (Stateless Tools)

Use the `@define_tool()` decorator for simple, stateless tools:

```python
from orchestral import define_tool

@define_tool()
def calculate_energy(mass: float, c: float = 299792458.0):
    """Calculate relativistic energy using E=mc²
    
    Args:
        mass: Mass in kilograms
        c: Speed of light in m/s (default: exact value)
    
    Returns:
        Energy in joules
    """
    energy = mass * c ** 2
    return f"E = mc² = ({mass} kg) × ({c} m/s)² = {energy:.3e} joules"

@define_tool()
def convert_temperature(value: float, from_unit: str, to_unit: str):
    """Convert between temperature scales
    
    Args:
        value: Temperature value to convert
        from_unit: Input unit ('C', 'F', or 'K')
        to_unit: Output unit ('C', 'F', or 'K')
    
    Returns:
        Converted temperature with units
    """
    conversions = {
        ('C', 'F'): lambda v: v * 9/5 + 32,
        ('F', 'C'): lambda v: (v - 32) * 5/9,
        ('C', 'K'): lambda v: v + 273.15,
        ('K', 'C'): lambda v: v - 273.15,
    }
    key = (from_unit.upper(), to_unit.upper())
    if key not in conversions:
        return f"Unsupported conversion: {from_unit} to {to_unit}"
    result = conversions[key](value)
    return f"{value}°{from_unit} = {result:.2f}°{to_unit}"
```

### 1.2 Class-Based Definition (Stateful Tools)

For tools with state or configuration, extend `BaseTool`:

```python
from orchestral.tools.base import BaseTool, RuntimeField

class DataAnalysisTool(BaseTool):
    """Analyze numerical dataset"""
    
    data_path: str | None = RuntimeField(
        description="Path to CSV data file"
    )
    method: str = RuntimeField(
        default="mean",
        description="Analysis method: mean, median, std"
    )
    
    def __init__(self, base_directory: str = None):
        self.base_directory = base_directory
    
    def _run(self) -> str:
        import pandas as pd
        import numpy as np
        
        # Handle relative paths
        if self.data_path and not os.path.isabs(self.data_path):
            if self.base_directory:
                full_path = os.path.join(self.base_directory, self.data_path)
            else:
                full_path = self.data_path
        else:
            full_path = self.data_path
            
        df = pd.read_csv(full_path)
        
        if self.method == "mean":
            result = df.mean()
        elif self.method == "median":
            result = df.median()
        elif self.method == "std":
            result = df.std()
        else:
            return f"Unknown method: {self.method}"
            
        return f"Analysis result:\n{result.to_string()}"
```

### 1.3 Type Hints and Schema Generation

**Automatic schema generation** from type hints:

```python
@define_tool()
def search_papers(query: str, year: int = 2024, max_results: int = 10):
    """Search academic papers"""
    pass

# Generates schema:
{
    "name": "search_papers",
    "description": "Search academic papers",
    "parameters": {
        "type": "object",
        "properties": {
            "query": {"type": "string", "description": "Search query"},
            "year": {"type": "integer", "description": "Filter by year", "default": 2024},
            "max_results": {"type": "integer", "description": "Max results", "default": 10}
        },
        "required": ["query"]
    }
}
```

---

## Built-in Tools

### 2.1 Filesystem Tools

```python
from orchestral.tools import (
    ReadFileTool, 
    WriteFileTool, 
    EditFileTool,
    FileSearchTool,
    FindFilesTool
)

# Configure with sandbox
base_directory = "workspace"
os.makedirs(base_directory, exist_ok=True)

tools = [
    ReadFileTool(base_directory=base_directory, show_line_numbers=True),
    WriteFileTool(base_directory=base_directory),
    EditFileTool(base_directory=base_directory),
    FileSearchTool(base_directory=base_directory),
    FindFilesTool(base_directory=base_directory),
]
```

| Tool | Description |
|------|-------------|
| `ReadFileTool` | Read file contents with optional line numbers |
| `WriteFileTool` | Create or overwrite files |
| `EditFileTool` | Make targeted modifications to files |
| `FileSearchTool` | Search for text patterns in files |
| `FindFilesTool` | Find files matching glob patterns |

### 2.2 Execution Tools

```python
from orchestral.tools import RunCommandTool, RunPythonTool

tools = [
    RunCommandTool(base_directory=base_directory),
    RunPythonTool(base_directory=base_directory),
]
```

| Tool | Description |
|------|-------------|
| `RunCommandTool` | Execute shell commands in sandbox |
| `RunPythonTool` | Execute Python code snippets |

### 2.3 Web Tools

```python
from orchestral.tools import WebSearchTool

tools = [
    WebSearchTool(),
]
```

| Tool | Description |
|------|-------------|
| `WebSearchTool` | Search the web for information |

### 2.4 Utility Tools

```python
from orchestral.tools import TodoWrite, TodoRead, DisplayImageTool

tools = [
    TodoRead(),       # Read todo list
    TodoWrite(),      # Write/update todo list
    DisplayImageTool, # Display images in UI
]
```

---

## Tool Execution Flow

### 3.1 Execution Sequence

```
LLM Response (Tool Call)
    ↓
Pre-Execution Hooks
    ├── Security Validation
    ├── Input Validation
    └── Approval Check (if enabled)
    ↓
Tool Execution
    ├── Sandbox Isolation
    ├── Function Call
    └── Result Processing
    ↓
Post-Execution Hooks
    ├── Output Validation
    └── Result Formatting
    ↓
Context Update
```

### 3.2 Error Handling

```python
try:
    result = tool._run(**validated_args)
except Exception as e:
    # Error is caught and formatted for the LLM
    return f"Error executing {tool.name}: {str(e)}"
```

---

## Tool Hooks (Security)

### 4.1 Hook System

Security and monitoring via pre/post execution hooks:

```python
from orchestral.tools.hooks import (
    UserApprovalHook,       # Require approval for sensitive operations
    DangerousCommandHook(), # Block dangerous patterns
    TruncateLinesHook(),    # Limit output size
    SafeguardHook()         # Additional safety measures
)

hooks = [
    UserApprovalHook(),
    DangerousCommandHook(),
    TruncateLinesHook(max_lines=1000),
]

agent = Agent(llm=llm, tools=tools, tool_hooks=hooks)
```

### 4.2 Hook Types

| Hook | Purpose |
|------|---------|
| `UserApprovalHook` | Require user approval for sensitive operations |
| `DangerousCommandHook` | Block dangerous commands (rm -rf, eval(), etc.) |
| `TruncateLinesHook` | Limit output to prevent overwhelming responses |
| `SafeguardHook` | Additional safety measures |

### 4.3 Dangerous Command Patterns

The `DangerousCommandHook` blocks:

```python
# Patterns that are blocked:
DANGEROUS_PATTERNS = [
    "rm -rf",      # Destructive file deletion
    "eval(",       # Code injection
    "exec(",       # Code execution
    "os.system",   # Shell execution
    "subprocess",  # Process spawning
    "chmod 777",   # Permission changes
    "sudo",        # Privilege escalation
    "curl | sh",   # Pipe to shell
    "wget | sh",   # Download and execute
]
```

---

## Workspace Sandboxing

### 5.1 Directory Structure

```
workspace/
├── data/           # Input data files
├── output/         # Generated files
├── temp/           # Temporary files
└── scripts/        # Helper scripts
```

### 5.2 Configuration

```python
base_directory = "workspace"
os.makedirs(base_directory, exist_ok=True)

tools = [
    ReadFileTool(base_directory=base_directory),
    WriteFileTool(base_directory=base_directory),
    RunCommandTool(base_directory=base_directory),
]
```

**Benefits:**
- Prevents access to sensitive system files
- Contains agent operations in isolated directory
- Easy cleanup by removing workspace directory

---

## Custom Tool Examples

### 6.1 Research Tool

```python
@define_tool()
def search_arxiv(query: str, max_results: int = 5):
    """Search arXiv for papers
    
    Args:
        query: Search query for arXiv
        max_results: Maximum number of results (default: 5)
    
    Returns:
        List of matching papers with titles and links
    """
    import urllib.request
    import urllib.parse
    import json
    
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
    
    # Parse ATOM feed and extract paper info
    # Return formatted results
    return "Parsed arXiv results..."
```

### 6.2 Database Tool

```python
@define_tool()
def query_database(sql: str, database: str = "research.db"):
    """Execute SQL query on database
    
    Args:
        sql: SQL query to execute
        database: Path to SQLite database
    
    Returns:
        Query results or error message
    """
    import sqlite3
    
    try:
        conn = sqlite3.connect(database)
        cursor = conn.cursor()
        cursor.execute(sql)
        
        if sql.strip().upper().startswith("SELECT"):
            results = cursor.fetchall()
            columns = [desc[0] for desc in cursor.description]
            return {"columns": columns, "rows": results}
        else:
            conn.commit()
            return f"Affected rows: {cursor.rowcount}"
    except Exception as e:
        return f"Database error: {str(e)}"
    finally:
        conn.close()
```

### 6.3 API Tool

```python
@define_tool()
def fetch_semantic_scholar(paper_id: str, fields: str = "title,authors,abstract,citationCount"):
    """Fetch paper metadata from Semantic Scholar
    
    Args:
        paper_id: Semantic Scholar paper ID or arXiv ID
        fields: Comma-separated list of fields to retrieve
    
    Returns:
        Paper metadata as JSON
    """
    import requests
    
    url = f"https://api.semanticscholar.org/graph/v1/paper/{paper_id}"
    params = {"fields": fields}
    
    response = requests.get(url, params=params)
    
    if response.status_code == 200:
        return response.json()
    else:
        return f"Error: {response.status_code} - {response.text}"
```

---

## Tool Configuration

### 7.1 Agent with Tools

```python
from orchestral import Agent
from orchestral.llm import Claude

tools = [
    ReadFileTool(base_directory="workspace"),
    WriteFileTool(base_directory="workspace"),
    RunCommandTool(base_directory="workspace"),
    WebSearchTool(),
]

agent = Agent(
    llm=Claude(model='claude-sonnet-4-0'),
    tools=tools,
    system_prompt="You are a research assistant with file and web access."
)
```

### 7.2 Tool Ordering

```python
# Order matters - first matching tool is used
tools = [
    # Specific tools first
    ReadFileTool(base_directory="workspace"),
    WriteFileTool(base_directory="workspace"),
    # General tools last
    RunCommandTool(base_directory="workspace"),
    WebSearchTool(),
]
```

---

## Best Practices

### 8.1 Tool Design

1. **Clear descriptions**: Write helpful docstrings
2. **Type safety**: Use proper type hints
3. **Error handling**: Return meaningful error messages
4. **Idempotency**: Tools should be safe to retry
5. **Single responsibility**: Each tool does one thing well

### 8.2 Security

1. **Sandbox all execution**: Use workspace isolation
2. **Block dangerous operations**: Use hooks
3. **Validate inputs**: Use type validation
4. **Limit outputs**: Use truncation hooks
5. **Require approval**: Use user approval hooks for sensitive operations

### 8.3 Performance

1. **Cache results**: For expensive operations
2. **Limit timeouts**: Prevent hanging
3. **Handle rate limits**: For external APIs
4. **Batch operations**: When possible

---

## Summary

| Feature | Description |
|---------|-------------|
| Function Tools | `@define_tool()` decorator for stateless tools |
| Class Tools | `BaseTool` for stateful tools |
| Automatic Schema | Type hints converted to JSON schemas |
| Built-in Tools | Filesystem, execution, web, utilities |
| Hook System | Security via pre/post execution hooks |
| Sandboxing | Workspace isolation for safety |
| Custom Tools | Easy to add domain-specific tools |

---

## Related Documentation

- [Architecture](architecture.md) - System design
- [Context](context.md) - State management
- [Examples](examples.md) - Complete usage examples

---

*Document Version: 1.0*
*Last Updated: January 2026*
*Source: Orchestral AI Documentation and arXiv Paper 2601.02577*
