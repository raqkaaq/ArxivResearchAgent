# LangGraph Providers

## Overview

LangGraph integrates with multiple LLM providers through LangChain. This document covers provider setup, configuration, and best practices.

---

## Supported Providers

### 1.1 Provider Matrix

| Provider | Models | Cost Level | API Type |
|----------|--------|------------|----------|
| **OpenAI** | GPT-4o, GPT-4, GPT-3.5 | $$$ | REST |
| **Anthropic** | Claude 3.5 Sonnet, Claude 3 Opus | $$$ | REST |
| **Google** | Gemini 1.5 Pro, Gemini 1.5 Flash | $$ | REST |
| **Groq** | Llama 3.1, Mixtral | $ | REST |
| **Ollama** | Llama 3.1, Mistral, Gemma | Free | Local |
| **AWS Bedrock** | Claude, Titan | $$$ | SDK |
| **Mistral AI** | Mixtral, Mistral Large | $$ | REST |

---

## Provider Setup

### 2.1 OpenAI

```python
from langchain_openai import ChatOpenAI
from langchain_openai import OpenAIEmbeddings

# Chat model
llm = ChatOpenAI(
    model="gpt-4o",
    temperature=0,
    max_tokens=4096,
    api_key="sk-proj-..."
)

# Embeddings
embeddings = OpenAIEmbeddings(
    model="text-embedding-3-small",
    api_key="sk-proj-..."
)

# Streaming
stream = llm.stream("Hello!")
for chunk in stream:
    print(chunk.content, end="", flush=True)
```

### 2.2 Anthropic

```python
from langchain_anthropic import ChatAnthropic

llm = ChatAnthropic(
    model="claude-sonnet-4-20250514",
    temperature=0,
    max_tokens=4096,
    api_key="sk-ant-api03-..."
)

# Using Bedrock (AWS)
from langchain_anthropic import ChatAnthropicBedrock

llm = ChatAnthropicBedrock(
    model_id="anthropic.claude-sonnet-4-20250514",
    region_name="us-east-1",
    aws_access_key_id="...",
    aws_secret_access_key="..."
)
```

### 2.3 Google Gemini

```python
from langchain_google_vertexai import ChatVertexAI
from langchain_google_vertexai import VertexAIEmbeddings

# Vertex AI (production)
llm = ChatVertexAI(
    model="gemini-1.5-pro",
    temperature=0,
    api_key="AIza..."
)

# Direct Gemini API
from langchain_google_genai import ChatGoogleGenerativeAI

llm = ChatGoogleGenerativeAI(
    model="gemini-1.5-pro",
    google_api_key="AIza..."
)
```

### 2.4 Groq

```python
from langchain_groq import ChatGroq

llm = ChatGroq(
    model="llama-3.1-70b-versatile",
    temperature=0,
    groq_api_key="gsk_..."
)

# Alternative models
llm = ChatGroq(
    model="mixtral-8x7b-32768",
    temperature=0.5
)
```

### 2.5 Ollama (Local)

```python
from langchain_ollama import ChatOllama
from langchain_ollama import OllamaEmbeddings

# Chat model
llm = ChatOllama(
    model="llama3.1:70b",
    temperature=0,
    base_url="http://localhost:11434"
)

# Smaller models for testing
llm = ChatOllama(
    model="llama3.2:3b",
    temperature=0.1
)

# Embeddings
embeddings = OllamaEmbeddings(
    model="nomic-embed-text",
    base_url="http://localhost:11434"
)
```

### 2.6 AWS Bedrock

```python
from langchain_aws import ChatBedrock
from langchain_aws import BedrockEmbeddings

# Claude via Bedrock
llm = ChatBedrock(
    model_id="anthropic.claude-3-5-sonnet-20241022",
    region_name="us-east-1",
    provider="anthropic"
)

# Titan via Bedrock
embeddings = BedrockEmbeddings(
    model_id="amazon.titan-embed-text-v1",
    region_name="us-east-1"
)
```

---

## Environment Configuration

### 3.1 Environment Variables

```env
# .env file
OPENAI_API_KEY=sk-proj-...
ANTHROPIC_API_KEY=sk-ant-api03-...
GOOGLE_API_KEY=AIza...
GROQ_API_KEY=gsk_...

# AWS Bedrock
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1

# Ollama
OLLAMA_BASE_URL=http://localhost:11434
```

### 3.2 Loading from Environment

```python
import os
from dotenv import load_dotenv

load_dotenv()

llm = ChatOpenAI(
    model="gpt-4o",
    api_key=os.getenv("OPENAI_API_KEY")
)
```

---

## Provider Selection

### 4.1 Dynamic Provider Selection

```python
from typing import Literal
from langchain_openai import ChatOpenAI
from langchain_anthropic import ChatAnthropic
from langchain_groq import ChatGroq

class LLMConfig(TypedDict):
    provider: Literal["openai", "anthropic", "groq"]
    model: str
    temperature: float

def create_llm(config: LLMConfig):
    """Factory for creating LLM instances"""
    if config["provider"] == "openai":
        return ChatOpenAI(
            model=config["model"],
            temperature=config["temperature"]
        )
    elif config["provider"] == "anthropic":
        return ChatAnthropic(
            model=config["model"],
            temperature=config["temperature"]
        )
    elif config["provider"] == "groq":
        return ChatGroq(
            model=config["model"],
            temperature=config["temperature"]
        )
    raise ValueError(f"Unknown provider: {config['provider']}")
```

### 4.2 Fallback Strategy

```python
def create_llm_with_fallback():
    """Create LLM with fallback providers"""
    providers = [
        ("anthropic", "claude-sonnet-4-20250514", 0.1),
        ("openai", "gpt-4o", 0.1),
        ("groq", "llama-3.1-70b-versatile", 0.1),
        ("ollama", "llama3.1:70b", 0.1),
    ]
    
    for provider, model, temp in providers:
        try:
            if provider == "anthropic":
                return ChatAnthropic(model=model, temperature=temp)
            elif provider == "openai":
                return ChatOpenAI(model=model, temperature=temp)
            elif provider == "groq":
                return ChatGroq(model=model, temperature=temp)
            elif provider == "ollama":
                return ChatOllama(model=model, temperature=temp)
        except Exception as e:
            print(f"Failed to create {provider}: {e}")
            continue
    
    raise Exception("All providers failed")
```

---

## Cost Tracking

### 5.1 Token Usage Tracking

```python
from langchain_core.callbacks import BaseCallbackHandler
from typing import Dict, Any

class CostTrackingHandler(BaseCallbackHandler):
    def __init__(self):
        self.total_tokens = 0
        self.total_cost = 0.0
    
    def on_llm_end(self, response: Any, **kwargs: Dict) -> None:
        usage = response.usage
        if usage:
            self.total_tokens += usage.total_tokens
            # Calculate cost (example rates)
            cost = (usage.prompt_tokens / 1_000_000) * 3.0 + \
                   (usage.completion_tokens / 1_000_000) * 15.0
            self.total_cost += cost

handler = CostTrackingHandler()
llm = ChatOpenAI(model="gpt-4o", callbacks=[handler])

response = llm.invoke("Hello")
print(f"Tokens: {handler.total_tokens}")
print(f"Cost: ${handler.total_cost:.4f}")
```

### 5.2 Per-Request Cost

```python
def estimate_cost(provider: str, model: str, tokens: int) -> float:
    """Estimate cost for a request"""
    rates = {
        ("openai", "gpt-4o"): 0.005,  # per 1K tokens
        ("openai", "gpt-4o-mini"): 0.00015,
        ("anthropic", "claude-sonnet-4-20250514"): 0.003,
        ("anthropic", "claude-haiku-4-20250514"): 0.00025,
        ("groq", "llama-3.1-70b-versatile"): 0.00059,
    }
    
    rate = rates.get((provider, model), 0.001)
    return (tokens / 1000) * rate
```

---

## Provider Comparison

### 6.1 Model Selection Guide

| Use Case | Recommended Provider | Model |
|----------|---------------------|-------|
| Complex reasoning | Anthropic | Claude 3 Opus |
| Fast responses | Groq | Llama 3.1 70B |
| Cost-effective | Groq | Llama 3.1 70B |
| Local testing | Ollama | Llama 3.2:3B |
| Multimodal | OpenAI | GPT-4o |
| Large context | Google | Gemini 1.5 Pro |

### 6.2 Context Windows

| Provider | Model | Context Window |
|----------|-------|----------------|
| OpenAI | GPT-4o | 128K tokens |
| Anthropic | Claude 3.5 Sonnet | 200K tokens |
| Google | Gemini 1.5 Pro | 2M tokens |
| Groq | Llama 3.1 | 128K tokens |
| Ollama | Varies | Depends on model |

---

## Best Practices

### 7.1 API Key Security

```python
# Good: Use environment variables
from dotenv import load_dotenv
load_dotenv()
api_key = os.getenv("ANTHROPIC_API_KEY")

# Bad: Hardcoded keys
api_key = "sk-ant-api03-..."
```

### 7.2 Error Handling

```python
from langchain_core.exceptions import APIError

def safe_llm_call(llm, prompt: str) -> str:
    """Call LLM with error handling"""
    try:
        return llm.invoke(prompt)
    except APIError as e:
        print(f"API Error: {e}")
        return fallback_llm.invoke(prompt)
    except Exception as e:
        print(f"Unexpected error: {e}")
        return "Error processing request"
```

### 7.3 Rate Limiting

```python
import time
from typing import Callable
from functools import wraps

def rate_limiter(calls: int, period: float):
    """Decorator for rate limiting"""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Implementation with time tracking
            pass
        return wrapper
    return decorator
```

---

## Summary

| Provider | Strengths | Best For |
|----------|-----------|----------|
| OpenAI | Mature, reliable | Production apps |
| Anthropic | Long context, reasoning | Complex tasks |
| Google | Multimodal, large context | Large documents |
| Groq | Fast, cheap | Real-time apps |
| Ollama | Free, local | Development, privacy |
| Bedrock | Enterprise, compliance | AWS deployments |

---

*Document Version: 1.0*
*Last Updated: January 2026*
