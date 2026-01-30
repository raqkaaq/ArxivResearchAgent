# Orchestral AI Context Management

## Overview

The Context class is the **central state management component** in Orchestral AI. It manages message history, validation, conversation persistence, and usage tracking.

**Source: Orchestral AI Documentation and arXiv Paper 2601.02577**

---

## Context Class Structure

### 1.1 Core Attributes

```python
from orchestral.context import Context

# Context typically contains:
context.messages: List[Message]      # Conversation history
context.usage: Usage                 # Cost tracking
context.metadata: Dict[str, Any]    # Additional context data
context.tools: List[Tool]           # Available tools schema
```

### 1.2 Key Methods

| Method | Description |
|--------|-------------|
| `add_message(message: Message)` | Add and validate a message |
| `remove_orphaned_tool_results()` | Clean unmatched tool results |
| `save_json(path: str)` | Serialize conversation to JSON file |
| `load_json(path: str)` | Load conversation from JSON file |
| `undo()` | Remove last message and response |
| `copy()` | Create a branch of current conversation |

---

## Basic Usage

### 2.1 Loading Context

```python
from orchestral.context import Context

# Load existing conversation
context = Context.load_json("conversation.json")

# Create agent with loaded context
agent = Agent(llm=GPT(model='gpt-4'), tools=tools, context=context)
```

### 2.2 Saving Context

```python
# Save current conversation
agent.context.save_json("conversation.json")

# Continue later with different provider
loaded_context = Context.load_json("conversation.json")
agent = Agent(llm=Claude(model='claude-sonnet-4-0'), tools=tools, context=loaded_context)
```

### 2.3 Agent with Context

```python
from orchestral import Agent
from orchestral.llm import Claude

# Create agent with context
agent = Agent(
    llm=Claude(),
    tools=tools,
    system_prompt="You are a helpful assistant."
)

# Context is automatically created
print(type(agent.context))  # <class 'orchestral.context.Context'>
```

---

## Context Features

### 3.1 Message History Management

```python
# Access conversation history
for message in agent.context.messages:
    print(f"{message.role}: {message.content[:100]}...")

# Get message count
message_count = len(agent.context.messages)

# Get last message
last_message = agent.context.messages[-1]
```

### 3.2 Cost Tracking

```python
# After each response
response = agent.run("Your query")
print(f"Cost: ${response.usage.cost:.4f}")
print(f"Input tokens: {response.usage.input_tokens}")
print(f"Output tokens: {response.usage.output_tokens}")

# Aggregated cost across conversation
total_cost = agent.context.usage.total_cost
print(f"Total conversation cost: ${total_cost:.4f}")
```

### 3.3 Undo Functionality

```python
# Remove last operation
agent.context.undo()

# Undo removes the last user message and assistant response
# Useful for correcting mistakes or exploring alternatives
```

### 3.4 Context Branching

```python
# Create a branch of current conversation
branched_context = agent.context.copy()

# Continue with different agent
branched_agent = Agent(llm=llm, tools=tools, context=branched_context)

# Original conversation remains unchanged
# Explore "what if" scenarios without affecting main conversation
```

---

## Context Validation

### 4.1 Message Validation

The Context validates all messages to ensure:
- Required fields are present
- Message roles are valid
- Tool calls and results are matched
- No orphaned tool results exist

```python
# Validation happens automatically on add_message
agent.context.add_message(user_message)
agent.context.add_message(assistant_message)  # With tool calls
agent.context.add_message(tool_result_message)  # Resolves tool calls
```

### 4.2 Integrity Protection

```python
# Detect external modifications
# The context tracks changes and can detect unauthorized modifications
# Useful in collaborative or multi-agent scenarios
```

### 4.3 Orphaned Tool Results

```python
# Clean up unmatched tool results
agent.context.remove_orphaned_tool_results()

# Ensures all tool results have corresponding tool calls
# Prevents state inconsistencies
```

---

## Persistence Options

### 5.1 Current Support: JSON Files

```python
# Save to file
agent.context.save_json("session_2026_01_30.json")

# Load from file
context = Context.load_json("session_2026_01_30.json")

# Provider-agnostic format
# Can load conversation created with Claude and continue with GPT
```

### 5.2 Serialized Format

**JSON Structure:**

```json
{
  "messages": [
    {
      "role": "user",
      "content": "Hello, help me with math.",
      "tool_calls": [],
      "tool_results": [],
      "usage": {
        "input_tokens": 10,
        "output_tokens": 50,
        "cost": 0.001
      },
      "metadata": {}
    }
  ],
  "usage": {
    "total_cost": 0.05,
    "total_input_tokens": 1000,
    "total_output_tokens": 5000
  },
  "metadata": {
    "created_at": "2026-01-30T10:00:00Z",
    "model": "claude-sonnet-4-0"
  }
}
```

### 5.3 Future Persistence Options

**Currently Requires Custom Implementation:**

1. **Redis Backend**
   ```python
   # Custom implementation needed
   class RedisContext(Context):
       def __init__(self, redis_client, session_id, ttl=3600):
           self.redis = redis_client
           self.session_id = session_id
           self.ttl = ttl
           
       def save_json(self, path=None):
           self.redis.setex(f"session:{self.session_id}", self.ttl, self.to_json())
           
       def load_json(self, path=None):
           data = self.redis.get(f"session:{self.session_id}")
           if data:
               self.from_json(data)
   ```

2. **PostgreSQL Backend**
   - Requires custom schema for conversations, messages, and tool calls
   - ORM mapping for Context objects
   - Transaction management for state updates

3. **Cloud Storage**
   - S3, Google Cloud Storage, Azure Blob Storage
   - Similar interface to JSON file persistence

---

## Multi-Agent Context Sharing

### 6.1 Separate Contexts

```python
# Each agent has its own context
agent_A = Agent(llm=GPT(), system_prompt="You are philosopher Quine.")
agent_B = Agent(llm=GPT(), system_prompt="You are philosopher Carnap.")

# No shared state between agents
```

### 6.2 Shared Context (Manual)

```python
# Create shared context
shared_context = Context()

# Both agents use same context
agent_A = Agent(llm=GPT(), context=shared_context)
agent_B = Agent(llm=GPT(), context=shared_context)

# Both agents see the same conversation
# Useful for collaborative scenarios
```

### 6.3 Cross-Agent Cost Tracking

```python
# Total cost across multiple agents
total_cost = agent_A.context.usage.total_cost + agent_B.context.usage.total_cost
print(f"Total cost: ${total_cost:.4f}")
```

---

## Best Practices

### 7.1 Session Management

```python
# Create new session
def start_session(session_id: str) -> Agent:
    context = Context.load_json(f"sessions/{session_id}.json")
    return Agent(llm=Claude(), tools=tools, context=context)

# Save session
def save_session(agent: Agent, session_id: str):
    agent.context.save_json(f"sessions/{session_id}.json")
```

### 7.2 Cost Management

```python
# Set cost limits
MAX_COST_PER_SESSION = 10.00

def check_cost_limit(context: Context) -> bool:
    return context.usage.total_cost < MAX_COST_PER_SESSION

# Before each request
if not check_cost_limit(agent.context):
    raise Exception("Session cost limit exceeded")
```

### 7.3 Context Pruning

For long conversations, consider:
- **Manual truncation**: Remove oldest messages
- **Summarization**: Replace old messages with summary
- **Windowing**: Keep only recent N messages

```python
# Keep only last 50 messages
if len(agent.context.messages) > 50:
    # Create summary and replace old messages
    summary = summarize_messages(agent.context.messages[:-50])
    agent.context.messages = [summary] + agent.context.messages[-50:]
```

---

## Context in Programmatic Usage

### 8.1 Direct Context Access

```python
agent = Agent(llm=Claude())

# Access context directly
print(f"Messages: {len(agent.context.messages)}")
print(f"Total cost: ${agent.context.usage.total_cost:.4f}")

# Add custom metadata
agent.context.metadata["session_name"] = "research_session"
agent.context.metadata["user_id"] = "user_123"
```

### 8.2 Custom Context Subclass

```python
class ResearchContext(Context):
    """Extended context for research sessions"""
    
    def __init__(self, *args, research_topic: str = None, **kwargs):
        super().__init__(*args, **kwargs)
        self.research_topic = research_topic
        self.papers_reviewed = []
        
    def add_paper(self, paper_info: dict):
        self.papers_reviewed.append(paper_info)
        
    def get_paper_summary(self) -> str:
        return f"Reviewed {len(self.papers_reviewed)} papers on {self.research_topic}"
```

---

## Summary

| Feature | Status | Notes |
|---------|--------|-------|
| Message History | ✅ Full | List of all messages with validation |
| Cost Tracking | ✅ Full | Automatic token and cost monitoring |
| JSON Persistence | ✅ Full | `save_json()` / `load_json()` |
| Undo Function | ✅ Full | Remove last operation |
| Branching | ✅ Full | `copy()` for creating branches |
| Redis Backend | ❌ Custom | Requires implementation |
| PostgreSQL Backend | ❌ Custom | Requires implementation |
| Auto-Compaction | ❌ Custom | Manual management required |

---

## Related Documentation

- [Architecture](architecture.md) - System design overview
- [Tools](tools.md) - Tool execution and hooks
- [Examples](examples.md) - Complete usage examples

---

*Document Version: 1.0*
*Last Updated: January 2026*
*Source: Orchestral AI Documentation and arXiv Paper 2601.02577*
