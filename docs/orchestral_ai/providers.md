# Orchestral AI Providers

## Overview

Orchestral AI provides a **unified interface** across multiple LLM providers. This abstraction allows you to switch between providers without changing your application code.

**Source: Orchestral AI Documentation and arXiv Paper 2601.02577**

---

## Supported Providers

### 1.1 Provider Matrix

| Provider | Models | Cost Level | API Type |
|----------|--------|------------|----------|
| **Anthropic** | Claude Sonnet, Haiku, Opus | $$$ | REST |
| **OpenAI** | GPT-4o, GPT-4, GPT-3.5 | $$$ | REST |
| **Google** | Gemini 2.0, Gemini 1.5 | $$ | REST |
| **Groq** | Llama 3.1, Mixtral | $ | REST |
| **Mistral AI** | Mixtral, Mistral Large | $$ | REST |
| **AWS Bedrock** | Claude, Titan | $$$ | SDK |
| **Ollama** | Llama 3.1, Mistral, Gemma | Free | Local |

---

## Provider Setup

### 2.1 Environment Configuration

Create a `.env` file:

```env
# Anthropic (Claude)
ANTHROPIC_API_KEY=sk-ant-api03-...

# OpenAI (GPT)
OPENAI_API_KEY=sk-proj-...

# Google (Gemini)
GOOGLE_API_KEY=AIza...

# Groq (Llama, Mixtral)
GROQ_API_KEY=gsk_...

# AWS Bedrock
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1

# Ollama (Local - no API key needed)
# Just ensure Ollama is running locally
```

### 2.2 Provider Selection

```python
from orchestral.llm import Claude, GPT, Gemini, Ollama, Groq

# Choose provider by uncommenting one line:
llm = Claude(model='claude-sonnet-4-0')
# llm = GPT(model='gpt-4o')
# llm = Gemini(model='gemini-2.0-flash-exp')
# llm = Groq(model='llama-3.1-70b-versatile')
# llm = Ollama(model='llama3.1:70b')

agent = Agent(llm=llm, tools=tools)
```

---

## Provider Details

### 3.1 Anthropic (Claude)

```python
from orchestral.llm import Claude

# Recommended models
llm = Claude(model='claude-sonnet-4-0')     # Best balance
# llm = Claude(model='claude-haiku-4-0')   # Fast, efficient
# llm = Claude(model='claude-opus-4-0')    # Most capable

# Usage
agent = Agent(llm=llm, tools=tools)
```

**Characteristics:**
- Excellent reasoning and instruction following
- Large context window (200K+ tokens)
- Strong tool calling capabilities
- Higher cost per token

### 3.2 OpenAI (GPT)

```python
from orchestral.llm import GPT

# Recommended models
llm = GPT(model='gpt-4o')          # Best balance
# llm = GPT(model='gpt-4o-mini')   # Fast, cost-effective
# llm = GPT(model='gpt-4')         # Most capable
# llm = GPT(model='gpt-3.5-turbo') # Budget option

agent = Agent(llm=llm, tools=tools)
```

**Characteristics:**
- Widely used and well-documented
- Good tool calling support
- Moderate pricing
- Extensive ecosystem

### 3.3 Google (Gemini)

```python
from orchestral.llm import Gemini

# Recommended models
llm = Gemini(model='gemini-2.0-flash-exp')   # Fast, capable
# llm = Gemini(model='gemini-1.5-flash')     # Efficient
# llm = Gemini(model='gemini-1.5-pro')       # High capability

agent = Agent(llm=llm, tools=tools)
```

**Characteristics:**
- Multimodal capabilities (text, images, video)
- Large context window (2M+ tokens)
- Competitive pricing
- Native Google integration

### 3.4 Groq

```python
from orchestral.llm import Groq

# Recommended models
llm = Groq(model='llama-3.1-70b-versatile')   # Fast inference
# llm = Groq(model='llama-3.1-8b-instant')    # Very fast
# llm = Groq(model='mixtral-8x7b-32768')      # Good for long context

agent = Agent(llm=llm, tools=tools)
```

**Characteristics:**
- Extremely fast inference
- Lowest cost per token
- Llama-based models
- Great for real-time applications

### 3.5 Ollama (Local)

```python
from orchestral.llm import Ollama

# Install Ollama first: https://ollama.com
# Pull a model: ollama pull llama3.1:70b

llm = Ollama(model='llama3.1:70b')
# llm = Ollama(model='llama3.2:3b')         # Smaller, faster
# llm = Ollama(model='mistral:7b')          # Good balance
# llm = Ollama(model='gemma:7b')            # Google's model

agent = Agent(llm=llm, tools=tools)
```

**Characteristics:**
- Completely free (runs locally)
- No API calls or network latency
- Full privacy (data never leaves machine)
- Requires local GPU/CPU resources
- Slower than cloud providers

**Setup:**
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
ollama serve

# Pull a model (in separate terminal)
ollama pull llama3.1:70b
```

---

## Cost Tracking

### 4.1 Per-Request Cost

```python
agent = Agent(llm=Claude(), tools=tools)

response = agent.run("Your query here")
print(f"Cost: ${response.usage.cost:.4f}")
print(f"Input tokens: {response.usage.input_tokens}")
print(f"Output tokens: {response.usage.output_tokens}")
```

### 4.2 Aggregated Cost

```python
# Total cost across conversation
total_cost = agent.context.usage.total_cost
print(f"Session cost: ${total_cost:.4f}")
```

### 4.3 Provider Comparison

```python
providers = {
    "Claude": ("claude-sonnet-4-0", 3.00, 15.00),  # $/M tokens (input, output)
    "GPT-4o": ("gpt-4o", 2.50, 10.00),
    "Gemini": ("gemini-2.0-flash-exp", 0.10, 0.40),
    "Groq": ("llama-3.1-70b", 0.05, 0.08),
    "Ollama": ("llama3.1:70b", 0.00, 0.00),  # Free!
}

def estimate_cost(provider, input_tokens, output_tokens):
    model, input_cost, output_cost = providers[provider]
    return (input_tokens / 1_000_000) * input_cost + (output_tokens / 1_000_000) * output_cost
```

---

## Multi-Provider Usage

### 5.1 Switching Providers

```python
from orchestral import Agent
from orchestral.llm import Claude, GPT, Gemini, Ollama, Groq
from orchestral.tools import WebSearchTool

# Create same agent with different providers
providers = [
    ("Claude", Claude(model='claude-sonnet-4-0')),
    ("GPT-4o", GPT(model='gpt-4o')),
    ("Gemini", Gemini(model='gemini-2.0-flash-exp')),
]

for name, llm in providers:
    agent = Agent(
        llm=llm,
        tools=[WebSearchTool()],
    )
    response = agent.run("Summarize the latest AI news")
    print(f"{name}: {response.text[:200]}...")
    print(f"Cost: ${response.usage.cost:.4f}\n")
```

### 5.2 Fallback Strategy

```python
from orchestral import Agent
from orchestral.llm import Claude, GPT, Ollama

def create_agent_with_fallback():
    """Create agent with fallback providers"""
    providers = [
        (Claude, {'model': 'claude-sonnet-4-0'}),  # Primary
        (GPT, {'model': 'gpt-4o'}),                # Fallback 1
        (Ollama, {'model': 'llama3.1:70b'}),       # Fallback 2 (local)
    ]
    
    for provider_class, kwargs in providers:
        try:
            llm = provider_class(**kwargs)
            return Agent(llm=llm, tools=tools)
        except Exception as e:
            print(f"Failed to create {provider_class.__name__}: {e}")
            continue
    
    raise Exception("All providers failed")

agent = create_agent_with_fallback()
```

### 5.3 Cost-Based Selection

```python
def create_optimal_agent(query_length: int):
    """Select provider based on query characteristics"""
    
    # Short queries: Use fast/cheap providers
    if query_length < 100:
        llm = Groq(model='llama-3.1-70b-versatile')
    # Complex queries: Use capable providers
    else:
        llm = Claude(model='claude-sonnet-4-0')
    
    return Agent(llm=llm, tools=tools)
```

---

## Provider-Specific Notes

### 6.1 Rate Limits

| Provider | Rate Limit | Notes |
|----------|------------|-------|
| Anthropic | 50 req/min (default) | Can increase with tier |
| OpenAI | 500 req/min (GPT-4) | Varies by tier |
| Google | 15 req/min (default) | Increases with quota |
| Groq | Very high | Optimized for speed |
| Ollama | None | Local resource limits |

### 6.2 Context Windows

| Provider | Context Window |
|----------|----------------|
| Anthropic Claude | 200K tokens |
| OpenAI GPT-4o | 128K tokens |
| Google Gemini | 2M tokens |
| Groq Llama | 128K tokens |
| Ollama | Varies by model |

### 6.3 Tool Calling Support

| Provider | Tool Calling | Notes |
|----------|--------------|-------|
| Claude | ✅ Excellent | Best tool calling |
| GPT-4o | ✅ Good | Reliable tool calls |
| Gemini | ✅ Good | Native support |
| Groq | ⚠️ Limited | May need testing |
| Ollama | ⚠️ Variable | Depends on model |

---

## Environment-Specific Setup

### 7.1 Development

```python
# .env.development
ANTHROPIC_API_KEY=sk-ant-dev-...
OPENAI_API_KEY=sk-proj-dev-...
```

### 7.2 Production

```python
# .env.production
ANTHROPIC_API_KEY=sk-ant-prod-...
# Use separate keys for production
```

### 7.3 Docker/Container

```dockerfile
# Pass API keys via environment variables
ENV ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
ENV OPENAI_API_KEY=${OPENAI_API_KEY}
```

---

## Best Practices

### 8.1 API Key Security

1. **Never commit keys to version control**
2. **Use environment variables**
3. **Implement key rotation policies**
4. **Use separate keys per environment**

### 8.2 Cost Management

1. **Set budget alerts** for each provider
2. **Use cheaper providers** for simple tasks
3. **Implement rate limiting** in your application
4. **Cache responses** when appropriate

### 8.3 Provider Selection

1. **Test multiple providers** for your use case
2. **Benchmark** cost and performance
3. **Have fallbacks** for provider outages
4. **Monitor usage** and adjust strategy

---

## Summary

| Provider | Best For | Cost | Speed | Tool Calling |
|----------|----------|------|-------|--------------|
| Claude | Complex reasoning | $$$ | Medium | Excellent |
| GPT-4o | General purpose | $$$ | Fast | Good |
| Gemini | Multimodal | $$ | Fast | Good |
| Groq | Real-time | $ | Very Fast | Limited |
| Ollama | Privacy/Cost | Free | Variable | Variable |

---

## Related Documentation

- [Architecture](architecture.md) - System design
- [Context](context.md) - Cost tracking
- [Examples](examples.md) - Provider examples

---

*Document Version: 1.0*
*Last Updated: January 2026*
*Source: Orchestral AI Documentation and arXiv Paper 2601.02577*
