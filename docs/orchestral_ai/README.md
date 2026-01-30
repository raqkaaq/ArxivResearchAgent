# Orchestral AI Framework Documentation

## Overview

This comprehensive documentation covers the Orchestral AI framework for building LLM-powered agents. Orchestral AI is a lightweight, type-safe Python framework that provides a unified interface across multiple LLM providers while maintaining simplicity for scientific computing and production deployment.

**Sources:**
- Main Repository: https://github.com/orchestralAI/orchestral-ai
- Documentation: https://orchestral-ai.com/docs
- Paper: arXiv:2601.02577 ("Orchestral AI: A Framework for Agent Orchestration")
- Author: Alexander Roman (alex@orchestral-ai.com)

---

## Documentation Structure

| Document | Description |
|----------|-------------|
| [README](README.md) | Overview, quickstart, and navigation |
| [Architecture](architecture.md) | Core design principles and system architecture |
| [Context Management](context.md) | Context class, state management, and persistence |
| [Tools](tools.md) | Tool definition, execution, and built-in tools |
| [Providers](providers.md) | LLM provider integration (OpenAI, Anthropic, etc.) |
| [Messages](messages.md) | Message types, formats, and universal representation |
| [Examples](examples.md) | Comprehensive code examples and patterns |
| [API Reference](api.md) | Complete API documentation |
| [Design Decisions](design.md) | Architectural choices and rationale |
| [Limitations](limitations.md) | Current limitations and future directions |

---

## Quick Start

### Installation

```bash
pip install orchestral-ai
```

**Requirements:**
- Python 3.13 or higher (mandatory)
- At least one LLM provider API key
- Operating System: macOS, Linux, or Windows

### Minimal Example (5 lines)

```python
from orchestral import Agent
import app.server as app_server

agent = Agent()
app_server.run_server(agent)
```

### Basic Agent with Tools

```python
import os
from orchestral import Agent
from orchestral.llm import Claude
from orchestral.tools import RunCommandTool, WriteFileTool, ReadFileTool
from orchestral.tools.hooks import UserApprovalHook, DangerousCommandHook
from orchestral.prompts import BASIC_APP_PROMPT

# Setup workspace
base_directory = "workspace"
os.makedirs(base_directory, exist_ok=True)

# Configure tools
tools = [
    RunCommandTool(base_directory=base_directory),
    WriteFileTool(base_directory=base_directory),
    ReadFileTool(base_directory=base_directory),
]

# Add safety hooks
hooks = [
    UserApprovalHook(),
    DangerousCommandHook(),
]

# Create agent
agent = Agent(
    llm=Claude(),
    tools=tools,
    tool_hooks=hooks,
    system_prompt=BASIC_APP_PROMPT
)
```

### Environment Setup

Create a `.env` file:

```env
ANTHROPIC_API_KEY=sk-ant-...     # For Claude
OPENAI_API_KEY=sk-proj-...       # For GPT
GOOGLE_API_KEY=AIza...           # For Gemini
GROQ_API_KEY=gsk_...             # For Groq models
```

---

## Key Features

1. **Multi-Provider Support**: Anthropic, OpenAI, Google, Groq, Mistral, AWS Bedrock, Ollama
2. **Type-Safe Tool Definition**: Automatic schema generation from Python type hints
3. **Synchronous Execution**: Deterministic behavior and straightforward debugging
4. **Streaming Support**: Real-time responses without server dependencies
5. **Safety & Security**: Multi-layered approval system and dangerous command blocking
6. **Cost Tracking**: Automatic usage monitoring and cost calculation
7. **Conversation Persistence**: Save/load conversations as JSON
8. **Modular Architecture**: Clean separation of concerns

---

## Framework Philosophy

Orchestral AI addresses the fundamental tension in LLM agent frameworks between:

- **Vendor Lock-in**: Provider-specific SDKs offer depth but create dependencies
- **Architectural Complexity**: Multi-package ecosystems obscure control flow

**Orchestral's Solution:**
- Unified, type-safe interface across all major LLM providers
- Single lightweight Python package
- Preserves simplicity required for scientific computing and production deployment

---

## Architecture Overview

The framework centers on three core components:

1. **LLM**: Provider abstraction layer (Claude, GPT, Gemini, etc.)
2. **Tools**: Type-safe tool framework with automatic schema generation
3. **Context**: Message history, validation, and conversation management

```
User Input
    ↓
Agent (Orchestrator)
    ├── LLM Provider → Unified Interface
    ├── Tools → Hook System → Execution
    └── Context → Validation → Persistence
    ↓
Response + Cost Tracking
```

---

## Next Steps

- Read the [Architecture](architecture.md) guide for deep dive into system design
- Explore [Context Management](context.md) for state and persistence
- Learn about [Tools](tools.md) for extending agent capabilities
- Check [Examples](examples.md) for ready-to-use code patterns
- Reference [API](api.md) for complete documentation

---

## Support

- **Email**: alex@orchestral-ai.com
- **Issues**: https://github.com/orchestralAI/orchestral-ai/issues
- **Repository**: https://github.com/orchestralAI/orchestral-ai

---

*Last Updated: January 2026*
*Documentation Version: 1.0*
