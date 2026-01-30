# Orchestral AI API Reference

## Overview

Complete API reference for the Orchestral AI framework.

**Source: Orchestral AI Documentation and arXiv Paper 2601.02577**

---

## Agent Class

### 1.1 Constructor

```python
class Agent:
    def __init__(
        self,
        llm: BaseLLM,
        tools: Optional[List[BaseTool]] = None,
        tool_hooks: Optional[List[BaseHook]] = None,
        system_prompt: Optional[str] = None,
        context: Optional[Context] = None
    ):
        """Initialize agent with LLM, tools, and configuration
        
        Args:
            llm: LLM provider instance (Claude, GPT, etc.)
            tools: List of tool instances
            tool_hooks: Security/monitoring hooks
            system_prompt: System prompt string
            context: Existing conversation context
        """
```

### 1.2 Methods

```python
# Execute query synchronously
def run(self, message: str, max_iterations: int = 8) -> Response:
    """Send message and get response
    
    Args:
        message: User input
        max_iterations: Max tool call loops (default: 8)
    
    Returns:
        Response object with text, usage, etc.
    """

# Stream response token by token
def stream_text_message(self, message: str) -> Generator[str]:
    """Stream response as generator
    
    Args:
        message: User input
    
    Yields:
        Text chunks as they're generated
    """

# Get total cost
def get_total_cost(self) -> float:
    """Get accumulated cost for this session
    
    Returns:
        Total cost in USD
    """
```

### 1.3 Properties

```python
# Access conversation context
agent.context: Context

# Access LLM
agent.llm: BaseLLM

# Access tools
agent.tools: List[BaseTool]
```

---

## LLM Classes

### 2.1 Base Classes

```python
class BaseLLM:
    """Abstract base class for LLM providers"""
    
    def complete(self, context: Context, stream: bool = False) -> Response:
        """Process context and return response
        
        Args:
            context: Conversation context
            stream: Whether to stream response
        
        Returns:
            Response object
        """
        
    def get_cost(self, usage: Usage) -> float:
        """Calculate cost for given usage
        
        Args:
            usage: Token usage information
        
        Returns:
            Cost in USD
        """
```

### 2.2 Provider Implementations

```python
# Anthropic Claude
class Claude(BaseLLM):
    def __init__(
        self,
        model: str = 'claude-sonnet-4-0',
        api_key: Optional[str] = None,
        max_tokens: int = 4096
    ):
        """Initialize Claude provider
        
        Models: claude-sonnet-4-0, claude-haiku-4-0, claude-opus-4-0
        """

# OpenAI GPT
class GPT(BaseLLM):
    def __init__(
        self,
        model: str = 'gpt-4o',
        api_key: Optional[str] = None,
        max_tokens: int = 4096
    ):
        """Initialize GPT provider
        
        Models: gpt-4o, gpt-4o-mini, gpt-4, gpt-3.5-turbo
        """

# Google Gemini
class Gemini(BaseLLM):
    def __init__(
        self,
        model: str = 'gemini-2.0-flash-exp',
        api_key: Optional[str] = None,
        max_tokens: int = 4096
    ):
        """Initialize Gemini provider
        
        Models: gemini-2.0-flash-exp, gemini-1.5-flash, gemini-1.5-pro
        """

# Groq
class Groq(BaseLLM):
    def __init__(
        self,
        model: str = 'llama-3.1-70b-versatile',
        api_key: Optional[str] = None
    ):
        """Initialize Groq provider
        
        Models: llama-3.1-70b-versatile, llama-3.1-8b-instant, mixtral-8x7b-32768
        """

# Ollama (Local)
class Ollama(BaseLLM):
    def __init__(
        self,
        model: str = 'llama3.1:70b',
        base_url: str = 'http://localhost:11434'
    ):
        """Initialize Ollama provider (local models)
        
        Models: llama3.1:70b, llama3.2:3b, mistral:7b, gemma:7b
        """
```

---

## Context Class

### 3.1 Constructor

```python
class Context:
    def __init__(
        self,
        messages: Optional[List[Message]] = None,
        usage: Optional[Usage] = None,
        metadata: Optional[Dict[str, Any]] = None
    ):
        """Initialize context
        
        Args:
            messages: List of messages (default: empty)
            usage: Usage tracking (default: empty)
            metadata: Additional metadata (default: empty dict)
        """
```

### 3.2 Methods

```python
# Add message with validation
def add_message(self, message: Message):
    """Add and validate message to context"""

# Clean up
def remove_orphaned_tool_results(self):
    """Remove tool results without matching calls"""

# Persistence
def save_json(self, path: str):
    """Serialize context to JSON file"""

@classmethod
def load_json(cls, path: str) -> 'Context':
    """Load context from JSON file"""

# State management
def undo(self):
    """Remove last message and response"""

def copy(self) -> 'Context':
    """Create a copy for branching"""
```

### 3.3 Properties

```python
context.messages: List[Message]       # Conversation history
context.usage: Usage                  # Aggregated usage
context.metadata: Dict[str, Any]     # Additional data
```

---

## Tool Classes

### 4.1 define_tool Decorator

```python
def define_tool(func: Callable) -> BaseTool:
    """Decorator to convert function to tool
    
    Args:
        func: Function with type hints and docstring
    
    Returns:
        BaseTool instance
    
    Example:
        @define_tool()
        def add(a: int, b: int) -> int:
            """Add two numbers"""
            return a + b
    """
```

### 4.2 Base Tool Class

```python
class BaseTool:
    name: str                          # Tool identifier
    description: str                   # Human-readable description
    
    def _run(self, **kwargs) -> str:
        """Execute tool logic
        
        Args:
            **kwargs: Tool arguments from LLM
        
        Returns:
            Result string
        """
        
    def get_schema(self) -> Dict:
        """Get JSON schema for tool
        
        Returns:
            Tool schema dictionary
        """
```

### 4.3 Built-in Tools

```python
# Filesystem
class ReadFileTool(BaseTool):
    def __init__(
        self,
        base_directory: str = ".",
        show_line_numbers: bool = False
    ):
        """Read file contents
        
        Args:
            base_directory: Sandbox root directory
            show_line_numbers: Include line numbers in output
        """

class WriteFileTool(BaseTool):
    def __init__(self, base_directory: str = "."):
        """Create or overwrite files"""

class EditFileTool(BaseTool):
    def __init__(self, base_directory: str = "."):
        """Edit file contents"""

class FileSearchTool(BaseTool):
    def __init__(self, base_directory: str = "."):
        """Search for text in files"""

class FindFilesTool(BaseTool):
    def __init__(self, base_directory: str = "."):
        """Find files matching glob patterns"""

# Execution
class RunCommandTool(BaseTool):
    def __init__(self, base_directory: str = "."):
        """Execute shell commands"""

class RunPythonTool(BaseTool):
    def __init__(self, base_directory: str = "."):
        """Execute Python code snippets"""

# Web
class WebSearchTool(BaseTool):
    """Search the web for information"""

# Utilities
class TodoWrite(BaseTool):
    """Write or update todo list"""

class TodoRead(BaseTool):
    """Read todo list"""

class DisplayImageTool(BaseTool):
    """Display images in UI"""
```

---

## Hook Classes

### 5.1 Base Hook Class

```python
class BaseHook:
    def pre_execute(self, tool: BaseTool, args: Dict) -> Dict:
        """Pre-execution hook
        
        Args:
            tool: Tool being executed
            args: Tool arguments
        
        Returns:
            Modified arguments (or raise exception)
        """
        
    def post_execute(self, tool: BaseTool, result: str) -> str:
        """Post-execution hook
        
        Args:
            tool: Tool that was executed
            result: Tool result
        
        Returns:
            Modified result (or raise exception)
        """
```

### 5.2 Built-in Hooks

```python
class UserApprovalHook(BaseHook):
    """Require user approval for sensitive operations"""

class DangerousCommandHook(BaseHook):
    """Block dangerous command patterns
    
    Blocks:
    - rm -rf
    - eval(
    - exec(
    - os.system
    - subprocess
    - sudo
    - curl | sh
    - wget | sh
    """

class TruncateLinesHook(BaseHook):
    def __init__(self, max_lines: int = 1000):
        """Limit output lines
        
        Args:
            max_lines: Maximum number of lines in output
        """

class SafeguardHook(BaseHook):
    """Additional safety measures"""
```

---

## Message Classes

### 6.1 Message Structure

```python
class Message:
    role: str                      # "system", "user", "assistant", "tool"
    content: str                   # Text content
    tool_calls: List[ToolCall]     # LLM-suggested tool calls
    tool_results: List[ToolResult] # Tool execution results
    usage: Usage                   # Token usage
    metadata: Dict[str, Any]       # Provider-specific metadata
```

### 6.2 Tool Call/Result

```python
class ToolCall:
    id: str                        # Unique identifier
    name: str                      # Tool name
    arguments: Dict[str, Any]      # Tool arguments

class ToolResult:
    call_id: str                   # Matches ToolCall.id
    name: str                      # Tool name
    result: str                    # Execution result
    error: Optional[str]           # Error message (if failed)
```

### 6.3 Usage

```python
class Usage:
    input_tokens: int              # Tokens in request
    output_tokens: int             # Tokens in response
    cost: float                    # Cost in USD
    
    # Aggregated (in Context)
    total_input_tokens: int
    total_output_tokens: int
    total_cost: float
```

---

## Response Class

### 7.1 Response Structure

```python
class Response:
    text: str                      # Response text
    usage: Usage                   # Token usage
    tool_calls: List[ToolCall]     # Any tool calls made
    stop_reason: str               # Why generation stopped
    metadata: Dict[str, Any]       # Provider-specific metadata
```

---

## Prompts Module

### 8.1 Built-in Prompts

```python
from orchestral.prompts import BASIC_APP_PROMPT

# BASIC_APP_PROMPT: Default helpful assistant prompt
# Custom prompts can be passed as string
```

---

## Server Module

### 9.1 Web Server

```python
import app.server as app_server

app_server.run_server(
    agent: Agent,
    host: str = "127.0.0.1",
    port: int = 8000,
    open_browser: bool = True,
    debug: bool = False
):
    """Run web interface for agent
    
    Args:
        agent: Agent instance
        host: Host to bind
        port: Port to listen on
        open_browser: Automatically open browser
        debug: Enable debug mode
    """
```

---

## Exceptions

### 10.1 Exception Types

```python
class OrchestralError(Exception):
    """Base exception"""

class ToolError(OrchestralError):
    """Tool execution error"""

class ValidationError(OrchestralError):
    """Message/context validation error"""

class ProviderError(OrchestralError):
    """LLM provider error"""

class CostLimitError(OrchestralError):
    """Cost limit exceeded"""
```

---

## Environment Variables

### 11.1 Required Variables

```env
# Anthropic
ANTHROPIC_API_KEY=sk-ant-...

# OpenAI
OPENAI_API_KEY=sk-proj-...

# Google
GOOGLE_API_KEY=AIza...

# Groq
GROQ_API_KEY=gsk_...

# AWS Bedrock
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
```

---

## Type Aliases

### 12.1 Common Types

```python
from typing import List, Dict, Optional, Generator, Any
from pathlib import Path

ToolList = List[BaseTool]
HookList = List[BaseHook]
JsonDict = Dict[str, Any]
TokenCount = int
CostUSD = float
```

---

## Summary

| Module | Key Classes |
|--------|-------------|
| `Agent` | Agent |
| `llm` | Claude, GPT, Gemini, Ollama, Groq |
| `Context` | Context, Message, Usage |
| `tools` | BaseTool, define_tool, ReadFileTool, etc. |
| `tools.hooks` | BaseHook, UserApprovalHook, DangerousCommandHook |
| `server` | run_server |

---

*Document Version: 1.0*
*Last Updated: January 2026*
*Source: Orchestral AI Documentation and arXiv Paper 2601.02577*
