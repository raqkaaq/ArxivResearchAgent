# Orchestral AI Examples

## Overview

This document provides comprehensive code examples for common Orchestral AI use cases.

**Source: Orchestral AI Documentation and arXiv Paper 2601.02577**

---

## Quick Examples

### 1.1 Minimal Example (5 lines)

```python
from orchestral import Agent
import app.server as app_server

agent = Agent()
app_server.run_server(agent)
```

### 1.2 Basic Agent

```python
from orchestral import Agent
from orchestral.llm import Claude

agent = Agent(
    llm=Claude(model='claude-sonnet-4-0'),
    system_prompt="You are a helpful assistant."
)

response = agent.run("What is machine learning?")
print(response.text)
```

### 1.3 With Cost Tracking

```python
from orchestral import Agent
from orchestral.llm import Claude

agent = Agent(llm=Claude())

response = agent.run("Explain quantum computing")
print(response.text)
print(f"Cost: ${response.usage.cost:.4f}")
print(f"Tokens: {response.usage.input_tokens} in, {response.usage.output_tokens} out")
```

---

## Tool Examples

### 2.1 Custom Tool Definition

```python
from orchestral import define_tool

@define_tool()
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

@define_tool()
def celsius_to_fahrenheit(celsius: float) -> str:
    """Convert Celsius to Fahrenheit"""
    fahrenheit = (celsius * 9/5) + 32
    return f"{celsius}°C = {fahrenheit:.1f}°F"
```

### 2.2 Using Custom Tools

```python
from orchestral import Agent
from orchestral.llm import Claude

tools = [calculate_bmi, celsius_to_fahrenheit]

agent = Agent(
    llm=Claude(),
    tools=tools,
    system_prompt="You are a health and science assistant."
)

# Agent will use tools when appropriate
response = agent.run("My weight is 70kg and height is 1.75m")
print(response.text)  # Agent calls calculate_bmi automatically

response = agent.run("Convert 25 degrees Celsius to Fahrenheit")
print(response.text)  # Agent calls celsius_to_fahrenheit
```

### 2.3 Filesystem Tools

```python
import os
from orchestral import Agent
from orchestral.llm import Claude
from orchestral.tools import ReadFileTool, WriteFileTool, EditFileTool

# Setup workspace
base_directory = "workspace"
os.makedirs(base_directory, exist_ok=True)

# Configure tools
tools = [
    ReadFileTool(base_directory=base_directory, show_line_numbers=True),
    WriteFileTool(base_directory=base_directory),
    EditFileTool(base_directory=base_directory),
]

# Create agent
agent = Agent(
    llm=Claude(),
    tools=tools,
    system_prompt="You are a coding assistant with file access."
)

# Write a file
agent.run("Write a Python function to calculate fibonacci to fib.py")

# Read the file
agent.run("Read fib.py and explain the code")

# Edit the file
agent.run("Add memoization to the fibonacci function")
```

### 2.4 Command Execution

```python
import os
from orchestral import Agent
from orchestral.llm import Claude
from orchestral.tools import RunCommandTool

base_directory = "workspace"
os.makedirs(base_directory, exist_ok=True)

tools = [
    RunCommandTool(base_directory=base_directory),
]

agent = Agent(
    llm=Claude(),
    tools=tools,
    system_prompt="You are a data science assistant."
)

# Run shell commands
response = agent.run("Run 'python -c \"print(2+2)\"'")
print(response.text)

response = agent.run("List files in workspace: ls -la")
print(response.text)
```

### 2.5 Web Search

```python
from orchestral import Agent
from orchestral.llm import Claude
from orchestral.tools import WebSearchTool

tools = [WebSearchTool()]

agent = Agent(
    llm=Claude(),
    tools=tools,
    system_prompt="You are a research assistant with web access."
)

response = agent.run("Search for latest advances in quantum computing 2025")
print(response.text)
```

---

## Streaming Examples

### 3.1 Basic Streaming

```python
from orchestral import Agent
from orchestral.llm import Claude

agent = Agent(
    llm=Claude(model='claude-sonnet-4-0'),
    system_prompt="You are a creative writer."
)

print("Streaming response:\n")
print("-" * 60)

for chunk in agent.stream_text_message("Write a short story about AI."):
    print(chunk, end='', flush=True)

print("\n" + "-" * 60)
```

### 3.2 Streaming with Progress

```python
from orchestral import Agent
from orchestral.llm import Claude

agent = Agent(llm=Claude())

query = "Explain how neural networks work"

print(f"Query: {query}\n")
print("Response (streaming):")

total_length = 0
for chunk in agent.stream_text_message(query):
    print(chunk, end='', flush=True)
    total_length += len(chunk)

print(f"\n\nTotal response length: {total_length} characters")
```

---

## Multi-Turn Conversation

### 4.1 Simple Conversation

```python
from orchestral import Agent
from orchestral.llm import Claude

agent = Agent(
    llm=Claude(),
    system_prompt="You are a helpful coding assistant."
)

# First turn
response = agent.run("What is a decorator in Python?")
print(f"Q1: What is a decorator in Python?")
print(f"A1: {response.text}\n")

# Second turn (context maintained)
response = agent.run("Can you show me an example?")
print(f"Q2: Can you show me an example?")
print(f"A2: {response.text}\n")

# Third turn
response = agent.run("How does @property work?")
print(f"Q3: How does @property work?")
print(f"A3: {response.text}")
```

### 4.2 Multi-Agent Conversation

```python
from orchestral import Agent
from orchestral.llm import GPT

# Create two agents with different personas
philosopher_A = "Quine"
philosopher_B = "Carnap"

agent_A = Agent(
    system_prompt=f"""You are the philosopher {philosopher_A}.
    Respond in the style of {philosopher_A}. Keep answers concise.
    You are having a debate with {philosopher_B}.""",
    llm=GPT(model="gpt-4o")
)

agent_B = Agent(
    system_prompt=f"""You are the philosopher {philosopher_B}.
    Respond in the style of {philosopher_B}. Keep answers concise.
    You are having a debate with {philosopher_A}.""",
    llm=GPT(model="gpt-4o")
)

# Start the debate
print(f"=== Debate: {philosopher_A} vs {philosopher_B} ===\n")

response = agent_A.run(
    f"Hello Mr. {philosopher_B}, it's me, {philosopher_A}. "
    "What are your thoughts on the analytic-synthetic distinction?"
)
print(f"{philosopher_A}: {response.text}\n")

# Continue for 3 rounds
for round_num in range(3):
    print(f"--- Round {round_num + 1} ---\n")
    response = agent_B.run(response.text)
    print(f"{philosopher_B}: {response.text}\n")
    response = agent_A.run(response.text)
    print(f"{philosopher_A}: {response.text}\n")

# Show total cost
total_cost = agent_A.context.usage.total_cost + agent_B.context.usage.total_cost
print(f"Total cost: ${total_cost:.4f}")
```

---

## Provider Examples

### 5.1 Switching Providers

```python
from orchestral import Agent
from orchestral.llm import Claude, GPT, Gemini, Ollama, Groq
from orchestral.tools import WebSearchTool

# Test same query with different providers
query = "What are the main challenges in AI alignment?"

providers = [
    ("Claude", Claude(model='claude-sonnet-4-0')),
    ("GPT-4o", GPT(model='gpt-4o')),
    ("Gemini", Gemini(model='gemini-2.0-flash-exp')),
    ("Groq", Groq(model='llama-3.1-70b-versatile')),
]

for name, llm in providers:
    agent = Agent(
        llm=llm,
        tools=[WebSearchTool()],
    )
    
    response = agent.run(query)
    print(f"=== {name} ===")
    print(f"Response: {response.text[:200]}...")
    print(f"Cost: ${response.usage.cost:.4f}\n")
```

### 5.2 Ollama (Local)

```python
from orchestral import Agent
from orchestral.llm import Ollama

# Ensure Ollama is running: ollama serve
# Ensure model is pulled: ollama pull llama3.1:70b

llm = Ollama(model='llama3.1:70b')

agent = Agent(
    llm=llm,
    system_prompt="You are a helpful assistant."
)

# No API costs - runs locally!
response = agent.run("Explain recursion to me")
print(response.text)

# Verify no cost
print(f"Cost: ${response.usage.cost:.4f}")  # Should be $0.0
```

---

## Persistence Examples

### 6.1 Saving/Loading Conversation

```python
from orchestral import Agent
from orchestral.llm import Claude

# Create agent
agent = Agent(
    llm=Claude(),
    system_prompt="You are a research assistant."
)

# Have a conversation
agent.run("What is quantum entanglement?")
agent.run("How is this used in computing?")
agent.run("What are the practical applications?")

# Save conversation
agent.context.save_json("quantum_research.json")

print("Conversation saved!")
```

### 6.2 Loading and Continuing

```python
from orchestral import Agent
from orchestral.llm import GPT
from orchestral.context import Context

# Load previous conversation
context = Context.load_json("quantum_research.json")

# Continue with different provider
agent = Agent(
    llm=GPT(model='gpt-4o'),
    context=context,
    system_prompt="You are a research assistant."
)

# Previous context is preserved
response = agent.run("Can you summarize what we discussed?")
print(response.text)

# Cost continues from previous conversation
print(f"Total session cost: ${agent.context.usage.total_cost:.4f}")
```

### 6.3 Branching Conversation

```python
from orchestral import Agent
from orchestral.llm import Claude

# Create main conversation
agent = Agent(llm=Claude())

agent.run("What is machine learning?")
agent.run("What are neural networks?")

# Create a branch to explore alternative direction
branched_context = agent.context.copy()
branched_agent = Agent(llm=Claude(), context=branched_context)

# Branch explores different topic
branched_agent.run("How is ML used in healthcare?")

# Original conversation unchanged
# Can continue main conversation
agent.run("What about deep learning?")

print(f"Main conversation messages: {len(agent.context.messages)}")
print(f"Branch conversation messages: {len(branched_agent.context.messages)}")
```

---

## Security Hooks

### 7.1 Adding Safety Hooks

```python
import os
from orchestral import Agent
from orchestral.llm import Claude
from orchestral.tools import RunCommandTool, WriteFileTool, ReadFileTool
from orchestral.tools.hooks import UserApprovalHook, DangerousCommandHook, TruncateLinesHook

base_directory = "workspace"
os.makedirs(base_directory, exist_ok=True)

tools = [
    RunCommandTool(base_directory=base_directory),
    WriteFileTool(base_directory=base_directory),
    ReadFileTool(base_directory=base_directory),
]

# Add safety hooks
hooks = [
    UserApprovalHook(),      # Require approval for sensitive operations
    DangerousCommandHook(),  # Block dangerous patterns (rm -rf, etc.)
    TruncateLinesHook(),     # Limit output size
]

agent = Agent(
    llm=Claude(),
    tools=tools,
    tool_hooks=hooks,
    system_prompt="You are a coding assistant."
)

# These will be blocked:
# agent.run("Run 'rm -rf /'")
# agent.run("Run 'eval(os.system(\"malicious\"))'")
```

### 7.2 Custom Hook

```python
from orchestral.tools.hooks import BaseHook

class CostLimitHook(BaseHook):
    """Block operations if cost exceeds limit"""
    
    def __init__(self, max_cost: float = 1.00):
        self.max_cost = max_cost
        
    def pre_execute(self, tool, args: dict) -> dict:
        # Could check estimated cost before execution
        return args
        
    def post_execute(self, tool, result: str) -> str:
        # Could log or limit results
        return result

hooks = [CostLimitHook(max_cost=0.50)]
agent = Agent(llm=Claude(), tools=tools, tool_hooks=hooks)
```

---

## Error Handling

### 8.1 Basic Error Handling

```python
from orchestral import Agent
from orchestral.llm import Claude

agent = Agent(llm=Claude())

try:
    response = agent.run("Your query")
    print(f"Response: {response.text}")
except Exception as e:
    print(f"Error: {e}")
```

### 8.2 Tool Error Handling

```python
from orchestral import define_tool

@define_tool()
def risky_operation(data: str) -> str:
    """An operation that might fail"""
    if "error" in data.lower():
        raise ValueError("Simulated error")
    return f"Processed: {data}"

tools = [risky_operation]
agent = Agent(llm=Claude(), tools=tools)

# Error is caught and formatted
response = agent.run("Try the operation with 'error' in input")
print(response.text)  # Shows error message

# Successful operation
response = agent.run("Try the operation with 'success' in input")
print(response.text)  # Shows successful result
```

---

## Research-Specific Examples

### 9.1 Paper Analysis Agent

```python
import os
from orchestral import Agent
from orchestral.llm import Claude
from orchestral.tools import ReadFileTool, WebSearchTool
from orbital.prompts import BASIC_APP_PROMPT

base_directory = "papers"
os.makedirs(base_directory, exist_ok=True)

tools = [
    ReadFileTool(base_directory=base_directory),
    WebSearchTool(),
]

agent = Agent(
    llm=Claude(model='claude-sonnet-4-0'),
    tools=tools,
    system_prompt="""You are a research assistant specialized in 
    analyzing academic papers. Help users understand key concepts,
    compare approaches, and identify relevant literature."""
)

# Analyze a paper
response = agent.run("Read paper.pdf and summarize the main contributions")
print(response.text)

# Search for related work
response = agent.run("Search for papers that cite this work")
print(response.text)
```

### 9.2 Data Analysis Agent

```python
import os
from orchestral import Agent
from orchestral.llm import Claude
from orchestral.tools import ReadFileTool, RunCommandTool

base_directory = "data"
os.makedirs(base_directory, exist_ok=True)

tools = [
    ReadFileTool(base_directory=base_directory),
    RunCommandTool(base_directory=base_directory),
]

agent = Agent(
    llm=Claude(),
    tools=tools,
    system_prompt="You are a data analysis assistant."
)

# Load and analyze data
response = agent.run("Load data.csv and calculate summary statistics")
print(response.text)

# Create visualization
response = agent.run("Create a histogram of the first column using Python")
print(response.text)
```

---

## Complete Production Example

```python
import os
from orchestral import Agent
from orchestral.llm import Claude
from orchestral.tools import (
    ReadFileTool, WriteFileTool, EditFileTool,
    RunCommandTool, WebSearchTool,
    TodoWrite, TodoRead
)
from orchestral.tools.hooks import (
    UserApprovalHook, DangerousCommandHook, TruncateLinesHook
)
from orchestral.prompts import BASIC_APP_PROMPT

# Setup
base_directory = "workspace"
os.makedirs(base_directory, exist_ok=True)

# Configure tools
tools = [
    ReadFileTool(base_directory=base_directory, show_line_numbers=True),
    WriteFileTool(base_directory=base_directory),
    EditFileTool(base_directory=base_directory),
    RunCommandTool(base_directory=base_directory),
    WebSearchTool(),
    TodoRead(),
    TodoWrite(),
]

# Add safety hooks
hooks = [
    UserApprovalHook(),
    DangerousCommandHook(),
    TruncateLinesHook(max_lines=500),
]

# Create agent
agent = Agent(
    llm=Claude(model='claude-sonnet-4-0'),
    tools=tools,
    tool_hooks=hooks,
    system_prompt=BASIC_APP_PROMPT
)

# Usage
response = agent.run("Help me build a web scraper")
print(response.text)
```

---

## Summary

This examples document covers:

| Category | Examples |
|----------|----------|
| Quick Start | Minimal, basic, cost tracking |
| Tools | Custom, filesystem, command, web |
| Streaming | Basic, with progress |
| Multi-Turn | Simple, multi-agent |
| Providers | Switching, Ollama (local) |
| Persistence | Save/load, branch |
| Security | Hooks, custom hooks |
| Error Handling | Basic, tool errors |
| Research | Paper analysis, data analysis |

---

*Document Version: 1.0*
*Last Updated: January 2026*
*Source: Orchestral AI Documentation and arXiv Paper 2601.02577*
