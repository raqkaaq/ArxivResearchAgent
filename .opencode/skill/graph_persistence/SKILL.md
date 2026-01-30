# Graph Persistence Skill

This skill handles Orchestral AI context/state persistence for agent execution and resumption.

## Documentation
For detailed architecture and patterns, reference:
- [Context Management](../../../../docs/orchestral_ai/context.md)
- [Architecture Overview](../../../../docs/orchestral_ai/architecture.md)

## Features
- Context persistence for state survival across interruptions.
- Session resumption capabilities.
- Integration with SQLite and PostgreSQL for hybrid state storage.

## Usage
Load for reliable agent execution with Orchestral AI. Ensures state survives interruptions and supports session resumption.

## Implementation
- Based on Orchestral AI persistence patterns for agents.
- Includes config for database-backed persistence.

## Code Examples
From Orchestral AI persistence patterns:

```python
from orchestral import Agent
from orchestral.llm import Claude
from orchestral.context import Context

# Create agent with context persistence
agent = Agent(
    llm=Claude(),
    system_prompt="You are a research agent..."
)

# Save context for later resumption
context = agent.context
context.save_json("session_state.json")

# Load context to resume
resumed_context = Context.load_json("session_state.json")
```

## Integration with Project
- Used in supervisor agent for CLI/automator subgraph state persistence.
- Enables BranchAgent to maintain branching context across interruptions.
- Coordinates with PostgreSQL and SQLite for hybrid state storage.