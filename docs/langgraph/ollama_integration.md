# LangGraph with Ollama Integration

## Overview

This guide covers integrating LangGraph with Ollama, a self-hosted model serving platform. Ollama allows you to run large language models locally, providing privacy, cost savings, and customization options for your LangGraph applications.

**Key Benefits:**
- Local model execution (privacy and security)
- Cost-effective (no API fees)
- Custom model support
- Offline capabilities
- GPU acceleration

---

## Ollama Setup

### 1.1 Installation

**macOS:**
```bash
brew install ollama
```

**Linux:**
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

**Windows:**
```powershell
# Using Windows Subsystem for Linux (WSL)
# Follow Linux installation steps
```

**Docker:**
```bash
docker run -d -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
```

### 1.2 Model Management

**Pull a model:**
```bash
ollama pull llama3.1:70b
ollama pull mistral:7b
ollama pull codellama:34b
```

**List available models:**
```bash
ollama list
```

**Remove a model:**
```bash
ollama rm llama3.1:70b
```

**Search for models:**
```bash
ollama search llama
```

---

## LangGraph Integration

### 2.1 Basic Chat Integration

```python
from langchain_ollama import ChatOllama
from langgraph.graph import StateGraph, END
from typing import TypedDict, List

class AgentState(TypedDict):
    messages: List[str]
    intermediate_steps: List[dict]
    result: str | None

# Create Ollama client
llm = ChatOllama(
    model="llama3.1:70b",
    temperature=0.1,
    base_url="http://localhost:11434"
)

# Agent node that uses Ollama
@tool
def ollama_agent(state: AgentState) -> AgentState:
    """Agent that uses Ollama for responses"""
    messages = state["messages"]
    
    # Use Ollama with tools
    llm_with_tools = llm.bind_tools([search_arxiv, analyze_paper])
    response = llm_with_tools.invoke(messages)
    
    return {
        "messages": [response],
        "intermediate_steps": state["intermediate_steps"] + [{"llm": response}],
        "result": response.content
    }

# Build graph
graph = StateGraph(AgentState)
graph.add_node("agent", ollama_agent)
graph.set_entry_point("agent")
graph.add_edge("agent", END)

app = graph.compile()
```

### 2.2 Embeddings Integration

```python
from langchain_ollama import OllamaEmbeddings
from langgraph.graph import StateGraph, END
from typing import TypedDict

class VectorState(TypedDict):
    documents: list[dict]
    query_vector: list[float] | None
    results: list[dict] | None

# Create embeddings client
embeddings = OllamaEmbeddings(
    model="llama3.1:70b",
    base_url="http://localhost:11434"
)

# Vector search node
@tool
def vector_search_node(state: VectorState) -> VectorState:
    """Node that performs vector search using Ollama embeddings"""
    documents = state["documents"]
    query = state.get("query", "")
    
    # Generate query vector
    query_vector = embeddings.embed_query(query)
    
    # Calculate similarities
    results = []
    for doc in documents:
        doc_vector = doc.get("vector", [])
        if doc_vector:
            similarity = cosine_similarity(query_vector, doc_vector)
            results.append({
                "document": doc,
                "similarity": similarity
            })
    
    # Sort by similarity
    results.sort(key=lambda x: x["similarity"], reverse=True)
    
    return {
        "documents": documents,
        "query_vector": query_vector,
        "results": results[:10]  # Top 10 results
    }
```

### 2.3 Custom Model Integration

```python
from langchain_ollama import ChatOllama
from typing import TypedDict

class CustomAgentState(TypedDict):
    messages: list[str]
    custom_model: str
    result: str | None

# Custom model configuration
llama2 = ChatOllama(
    model="llama2:13b",
    temperature=0.3,
    base_url="http://localhost:11434",
    system_prompt="You are a helpful assistant. Be concise and accurate."
)

mistral = ChatOllama(
    model="mistral:7b",
    temperature=0.1,
    base_url="http://localhost:11434",
    system_prompt="You are an expert researcher. Provide detailed analysis."
)

# Model selector node
@tool
def model_selector(state: CustomAgentState) -> CustomAgentState:
    """Select appropriate model based on task"""
    task = state.get("task", "general").lower()
    
    if "research" in task or "analysis" in task:
        llm = mistral
    elif "coding" in task or "programming" in task:
        llm = ChatOllama(
            model="codellama:34b",
            temperature=0.2,
            base_url="http://localhost:11434"
        )
    else:
        llm = llama2
    
    messages = state["messages"]
    response = llm.invoke(messages)
    
    return {
        "messages": [response],
        "custom_model": llm.model,
        "result": response.content
    }
```

---

## Advanced Patterns

### 3.1 Multi-Model Workflows

```python
from typing import TypedDict, Literal
from langgraph.graph import StateGraph, END

class MultiModelState(TypedDict):
    messages: list[str]
    task_type: Literal["research", "coding", "analysis", "general"]
    model_used: str | None
    result: str | None

# Different models for different tasks
models = {
    "research": ChatOllama(model="llama3.1:70b", temperature=0.1),
    "coding": ChatOllama(model="codellama:34b", temperature=0.2),
    "analysis": ChatOllama(model="llama3.1:8b", temperature=0.1),
    "general": ChatOllama(model="llama3.2:3b", temperature=0.3)
}

@tool
def task_router(state: MultiModelState) -> MultiModelState:
    """Route tasks to appropriate models"""
    task_type = state.get("task_type", "general")
    messages = state["messages"]
    
    # Select model based on task
    llm = models.get(task_type, models["general"])
    
    # Use model with tools
    llm_with_tools = llm.bind_tools([search_arxiv, analyze_paper, code_executor])
    response = llm_with_tools.invoke(messages)
    
    return {
        "messages": [response],
        "task_type": task_type,
        "model_used": llm.model,
        "result": response.content
    }

# Build multi-model graph
graph = StateGraph(MultiModelState)
graph.add_node("router", task_router)
graph.set_entry_point("router")
graph.add_edge("router", END)

app = graph.compile()
```

### 3.2 Streaming with Ollama

```python
import asyncio
from langchain_ollama import ChatOllama
from langgraph.graph import StateGraph, END

class StreamingState(TypedDict):
    messages: list[str]
    streaming_result: str
    tokens_generated: int

# Streaming Ollama client
streaming_llm = ChatOllama(
    model="llama3.1:70b",
    temperature=0.1,
    base_url="http://localhost:11434",
    stream=True
)

@tool
def streaming_agent(state: StreamingState) -> StreamingState:
    """Agent that streams responses from Ollama"""
    messages = state["messages"]
    
    # Stream response
    async def stream_response():
        response = await streaming_llm.agenerate(
            messages,
            stream="default"
        )
        
        streaming_result = ""
        tokens_generated = 0
        
        async for chunk in response:
            streaming_result += chunk.text
            tokens_generated += 1
            
            # Update state (this would need to be handled differently in production)
            # For demonstration, we'll just accumulate
        
        return streaming_result, tokens_generated
    
    # Run streaming in executor
    import concurrent.futures
    with concurrent.futures.ThreadPoolExecutor() as executor:
        result, tokens = executor.submit(stream_response).result()
    
    return {
        "messages": messages,
        "streaming_result": result,
        "tokens_generated": tokens
    }
```

### 3.3 Error Handling and Fallbacks

```python
from langchain_ollama import ChatOllama
from typing import TypedDict
import time

class RobustState(TypedDict):
    messages: list[str]
    attempts: int
    result: str | None
    error: str | None

# Ollama client with retry logic
llm = ChatOllama(
    model="llama3.1:70b",
    temperature=0.1,
    base_url="http://localhost:11434"
)

@tool
def robust_agent(state: RobustState) -> RobustState:
    """Agent with error handling and fallbacks"""
    messages = state["messages"]
    attempts = state.get("attempts", 0)
    
    try:
        # First attempt
        response = llm.invoke(messages)
        return {
            "messages": [response],
            "attempts": attempts + 1,
            "result": response.content,
            "error": None
        }
    except Exception as e:
        if attempts < 3:
            # Wait and retry
            time.sleep(2 ** attempts)  # Exponential backoff
            return {
                "messages": messages,
                "attempts": attempts + 1,
                "result": None,
                "error": str(e)
            }
        else:
            # Fallback to smaller model
            fallback_llm = ChatOllama(
                model="llama3.2:3b",
                temperature=0.1,
                base_url="http://localhost:11434"
            )
            
            try:
                response = fallback_llm.invoke(messages)
                return {
                    "messages": [response],
                    "attempts": attempts + 1,
                    "result": response.content,
                    "error": f"Fallback used: {str(e)}"
                }
            except Exception as fallback_error:
                return {
                    "messages": messages,
                    "attempts": attempts + 1,
                    "result": None,
                    "error": f"Both models failed: {str(e)}, {str(fallback_error)}"
                }
```

---

## State Management

### 4.1 State with Ollama Clients

```python
from typing import TypedDict, NotRequired

class OllamaAgentState(TypedDict):
    # Core state
    messages: list[str]
    result: str | None
    
    # Ollama-specific
    ollama_client: object | None
    model_name: str
    temperature: float
    
    # Execution metadata
    step_count: int
    error_count: int
    execution_time: float
    
    # Tool usage
    tools_used: list[str]
    tool_execution_history: list[dict]
    
    # Performance
    tokens_used: int
    response_time: float
    
    # Optional fields
    custom_context: NotRequired[dict]
    system_prompt: NotRequired[str]
```

### 4.2 State Updates with Ollama

```python
def ollama_state_update(state: OllamaAgentState) -> OllamaAgentState:
    """Update state after Ollama interaction"""
    # Example: Update tool usage
    if "tools_used" not in state:
        state["tools_used"] = []
    
    # Add tool usage tracking
    if "tool_execution_history" not in state:
        state["tool_execution_history"] = []
    
    # Update execution metadata
    state["step_count"] = state.get("step_count", 0) + 1
    
    return state
```

---

## Best Practices

### 5.1 Model Selection Guidelines

| Task Type | Recommended Model | Temperature | Notes |
|-----------|-------------------|-------------|-------|
| Research & Analysis | llama3.1:70b | 0.1 | High reasoning capability |
| Code Generation | codellama:34b | 0.2 | Code-specialized model |
| General Chat | llama3.2:3b | 0.3 | Fast and lightweight |
| Document Analysis | llama3.1:8b | 0.1 | Good balance of speed/quality |
| Math & Logic | deepseek-coder:33b | 0.1 | Strong reasoning capabilities |

### 5.2 Performance Optimization

**GPU Acceleration:**
```bash
# Enable GPU support
export OLLAMA_ENABLE_CUDA=1

# Check GPU usage
nvidia-smi
```

**Model Quantization:**
```bash
# Use quantized models for better performance
ollama pull llama3.1:70b-q4_K_M
ollama pull mistral:7b-q4_K_M
```

**Memory Management:**
```python
# Monitor memory usage
import psutil
import torch

def monitor_resources():
    """Monitor system resources"""
    memory_info = psutil.virtual_memory()
    gpu_memory = torch.cuda.get_device_properties(0).total_memory if torch.cuda.is_available() else 0
    
    return {
        "memory_percent": memory_info.percent,
        "available_gb": memory_info.available / (1024**3),
        "gpu_memory_gb": gpu_memory / (1024**3) if gpu_memory else 0
    }
```

### 5.3 Security Considerations

**Input Validation:**
```python
import re

def sanitize_input(user_input: str) -> str:
    """Sanitize user input for model safety"""
    # Remove potentially harmful content
    sanitized = re.sub(r'[<>{}]', '', user_input)
    sanitized = sanitized[:4000]  # Limit input length
    return sanitized
```

**Model Safety:**
```python
from langchain_openai import ChatOpenAI

# Use content filtering
from langchain_openai import ChatOpenAI
from langchain_openai import ChatOpenAI

# Create safety checker
@tool
def safety_checker(content: str) -> dict:
    """Check content for safety"""
    # Implement safety checks
    # Return safety scores
    return {
        "safe": True,
        "categories": [],
        "confidence": 0.95
    }
```

---

## Troubleshooting

### 6.1 Common Issues

**Issue: Ollama not running**
```bash
# Check if Ollama is running
curl http://localhost:11434/api/version

# Start Ollama
ollama serve
```

**Issue: Model not found**
```bash
# Check available models
ollama list

# Pull missing model
ollama pull llama3.1:70b
```

**Issue: Connection timeout**
```python
# Check base URL
llm = ChatOllama(
    model="llama3.1:70b",
    base_url="http://localhost:11434",  # Default
    timeout=30  # Increase timeout if needed
)
```

**Issue: GPU memory errors**
```bash
# Reduce model size
ollama pull llama3.1:8b

# Use CPU-only
export OLLAMA_ENABLE_CUDA=0
```

### 6.2 Debugging Tips

**Enable verbose logging:**
```python
import logging

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Log Ollama interactions
logger.debug(f"Sending to Ollama: {messages}")
```

**Check model compatibility:**
```python
# Verify model supports streaming
if not llm.model.supports_streaming:
    logger.warning(f"Model {llm.model} does not support streaming")
```

---

## Production Deployment

### 7.1 Environment Configuration

**.env file:**
```env
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.1:70b
OLLAMA_TEMPERATURE=0.1
OLLAMA_TIMEOUT=30
```

**Docker Compose:**
```yaml
version: '3.8'

services:
  ollama:
    image: ollama/ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    environment:
      - OLLAMA_ENABLE_CUDA=1  # Enable GPU if available

  langgraph_app:
    build: .
    ports:
      - "8000:8000"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    depends_on:
      - ollama

volumes:
  ollama_data:
```

### 7.2 Monitoring and Observability

**Metrics Collection:**
```python
from prometheus_client import Counter, Histogram

# Ollama metrics
ollama_requests = Counter('ollama_requests_total', 'Total Ollama requests')
ollama_errors = Counter('ollama_errors_total', 'Total Ollama errors')
ollama_latency = Histogram('ollama_latency_seconds', 'Ollama request latency')

@tool
def monitored_agent(state: AgentState) -> AgentState:
    """Agent with monitoring"""
    start_time = time.time()
    
    try:
        response = llm.invoke(state["messages"])
        ollama_requests.inc()
        return {
            "messages": [response],
            "result": response.content
        }
    except Exception as e:
        ollama_errors.inc()
        raise
    finally:
        latency = time.time() - start_time
        ollama_latency.observe(latency)
```

---

## Comparison with Cloud Providers

| Feature | Ollama (Local) | OpenAI | Anthropic | Google |
|---------|----------------|--------|-----------|--------|
| Cost | Free (compute only) | $$$ | $$$ | $$$ |
| Privacy | High | Low | Low | Low |
| Latency | Low (local) | Medium | Medium | Medium |
| Customization | High | Low | Low | Low |
| Model Selection | Large | Large | Large | Large |
| Offline | Yes | No | No | No |
| GPU Support | Yes | Yes | Yes | Yes |
| API Limits | None | Rate limits | Rate limits | Rate limits |

---

## Summary

Integrating Ollama with LangGraph provides:

1. **Privacy and Security**: Local model execution
2. **Cost Efficiency**: No API fees
3. **Customization**: Custom models and fine-tuning
4. **Performance**: Low latency with GPU acceleration
5. **Flexibility**: Wide range of model options
6. **Reliability**: Offline capabilities

**Key Integration Points:**
- `ChatOllama` for chat completions
- `OllamaEmbeddings` for vector search
- Custom model configuration
- State management with client tracking
- Error handling and fallbacks
- Performance monitoring and optimization

**Next Steps:**
1. Install Ollama and pull desired models
2. Configure LangGraph to use Ollama clients
3. Implement state management for Ollama interactions
4. Add monitoring and error handling
5. Deploy to production with proper resource management

---

*Last Updated: January 2026*
*Document Version: 1.0*