# Custom Tool Creation for Agents

This guide covers advanced patterns for creating custom tools that extend LangGraph agents with specialized capabilities for research, data processing, and external integrations.

## Overview

Custom tools are the building blocks that give agents the ability to interact with external systems, perform specialized computations, and access domain-specific knowledge. This guide covers advanced patterns beyond basic function tools.

## Advanced Tool Patterns

### 1. Multi-Modal Tools

Tools that handle multiple input types (text, images, files) for complex analysis.

```python
from langchain_core.tools import tool
from typing import Union
from PIL import Image
import io

@tool
def multi_modal_analyze(
    input: Union[str, Image.Image, bytes],
    analysis_type: str = "text"
) -> dict:
    """
    Analyze text, images, or files with different methods
    
    Args:
        input: Text string, PIL Image, or binary file data
        analysis_type: Type of analysis - 'text', 'image', 'document'
    
    Returns:
        Analysis results as dictionary
    """
    import textwrap
    
    if isinstance(input, str):
        # Text analysis
        if analysis_type == "text":
            return {
                "type": "text",
                "summary": textwrap.shorten(input, width=200),
                "word_count": len(input.split())
            }
        elif analysis_type == "document":
            return {
                "type": "document",
                "readability_score": calculate_readability(input),
                "key_phrases": extract_key_phrases(input)
            }
    
    elif isinstance(input, Image.Image):
        # Image analysis
        return {
            "type": "image",
            "dimensions": input.size,
            "format": input.format,
            "analysis": "Image processed successfully"
        }
    
    elif isinstance(input, bytes):
        # File analysis
        try:
            image = Image.open(io.BytesIO(input))
            return multi_modal_analyze(image, analysis_type="image")
        except:
            text = input.decode("utf-8", errors="ignore")
            return multi_modal_analyze(text, analysis_type="document")
    
    return {"error": "Unsupported input type"}
```

### 2. Stateful Tools

Tools that maintain internal state across multiple invocations for context-aware processing.

```python
from langchain_core.tools import BaseTool
from typing import List, Dict, Optional
from collections import deque
import hashlib

class StatefulResearchTool(BaseTool):
    name: str = "research_tracker"
    description: str = "Track research queries and maintain context"
    
    # Tool configuration
    max_history: int = 50
    min_similarity: float = 0.3
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.query_history: deque = deque(maxlen=self.max_history)
        self.context_cache: Dict[str, dict] = {}
    
    def _run(self, query: str, context: Optional[str] = None) -> dict:
        """Execute research with context awareness"""
        # Generate query fingerprint
        query_hash = hashlib.md5(query.encode()).hexdigest()[:8]
        
        # Check cache
        if query_hash in self.context_cache:
            cached = self.context_cache[query_hash]
            return {
                "cached": True,
                "result": cached["result"],
                "context": cached["context"]
            }
        
        # Search with context awareness
        result = self._search_with_context(query, context)
        
        # Update history and cache
        self.query_history.append({
            "query": query,
            "result": result,
            "timestamp": self._current_time()
        })
        
        self.context_cache[query_hash] = {
            "result": result,
            "context": context
        }
        
        return {
            "cached": False,
            "result": result,
            "context": context,
            "history_size": len(self.query_history)
        }
    
    def _search_with_context(self, query: str, context: Optional[str] = None) -> str:
        """Perform search with context awareness"""
        # Use context to refine search
        if context:
            refined_query = f"{context} {query}"
        else:
            refined_query = query
        
        # Execute search (implementation-specific)
        return f"Search results for: {refined_query}"
    
    def get_context(self, query: str) -> Optional[str]:
        """Get relevant context from history"""
        if not self.query_history:
            return None
        
        # Find most similar previous query
        best_match = None
        best_similarity = self.min_similarity
        
        for entry in self.query_history:
            similarity = self._calculate_similarity(query, entry["query"])
            if similarity > best_similarity:
                best_similarity = similarity
                best_match = entry["result"]
        
        return best_match
    
    def _calculate_similarity(self, query1: str, query2: str) -> float:
        """Calculate similarity between queries"""
        # Simple token overlap similarity
        tokens1 = set(query1.lower().split())
        tokens2 = set(query2.lower().split())
        
        if not tokens1 or not tokens2:
            return 0.0
        
        intersection = tokens1.intersection(tokens2)
        union = tokens1.union(tokens2)
        
        return len(intersection) / len(union)
    
    def _current_time(self) -> str:
        """Get current timestamp"""
        from datetime import datetime
        return datetime.now().isoformat()
```

### 3. Async/Await Tools

Tools that perform concurrent operations for improved performance.

```python
from langchain_core.tools import tool
import asyncio
from typing import List, Dict, Any

@tool
def async_research(query: str, sources: List[str] = ["arxiv", "semantic_scholar"]) -> Dict[str, Any]:
    """
    Perform concurrent research across multiple sources
    
    Args:
        query: Research query
        sources: List of sources to search
    
    Returns:
        Dictionary with results from each source
    """
    async def search_source(source: str, query: str) -> Dict[str, Any]:
        """Search a single source"""
        try:
            if source == "arxiv":
                return await self._search_arxiv(query)
            elif source == "semantic_scholar":
                return await self._search_semantic_scholar(query)
            elif source == "google_scholar":
                return await self._search_google_scholar(query)
            else:
                return {"error": f"Unknown source: {source}"}
        except Exception as e:
            return {"error": str(e)}
    
    async def gather_results() -> Dict[str, Any]:
        """Gather results from all sources"""
        tasks = [search_source(source, query) for source in sources]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        return {source: result for source, result in zip(sources, results)}
    
    # Execute concurrent searches
    return asyncio.run(gather_results())

@tool
def batch_process_papers(
    paper_ids: List[str],
    operations: List[str] = ["metadata", "abstract", "citations"]
) -> Dict[str, Any]:
    """
    Process multiple papers concurrently
    
    Args:
        paper_ids: List of paper identifiers
        operations: List of operations to perform
    
    Returns:
        Dictionary with results for each paper
    """
    async def process_paper(paper_id: str) -> Dict[str, Any]:
        """Process a single paper"""
        results = {}
        
        if "metadata" in operations:
            results["metadata"] = await self._get_metadata(paper_id)
        
        if "abstract" in operations:
            results["abstract"] = await self._get_abstract(paper_id)
        
        if "citations" in operations:
            results["citations"] = await self._get_citations(paper_id)
        
        return {paper_id: results}
    
    async def process_all() -> Dict[str, Any]:
        """Process all papers concurrently"""
        tasks = [process_paper(pid) for pid in paper_ids]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Flatten results
        flattened = {}
        for result in results:
            if isinstance(result, dict):
                flattened.update(result)
            else:
                flattened[str(result)] = {"error": str(result)}
        
        return flattened
    
    return asyncio.run(process_all())
```

### 4. Validation and Sanitization Tools

Tools that validate and sanitize inputs before processing.

```python
from langchain_core.tools import tool
from pydantic import BaseModel, ValidationError, validator
from typing import List, Dict, Any, Optional
import re

class PaperQuery(BaseModel):
    query: str
    max_results: int = 10
    filters: Dict[str, Any] = {}
    sort_by: str = "relevance"
    
    @validator('query')
    def validate_query(cls, v):
        if not v or len(v.strip()) < 3:
            raise ValueError('Query must be at least 3 characters long')
        return v.strip()
    
    @validator('max_results')
    def validate_max_results(cls, v):
        if v < 1 or v > 100:
            raise ValueError('max_results must be between 1 and 100')
        return v
    
    @validator('filters', pre=True)
    def validate_filters(cls, v):
        if not isinstance(v, dict):
            raise ValueError('filters must be a dictionary')
        return v

@tool
def validated_search(query: str, **kwargs) -> Dict[str, Any]:
    """
    Search with input validation and sanitization
    
    Args:
        query: Search query
        **kwargs: Additional parameters
    
    Returns:
        Search results with validation metadata
    """
    try:
        # Validate and sanitize input
        validated = PaperQuery(query=query, **kwargs)
        
        # Sanitize query
        sanitized_query = self._sanitize_query(validated.query)
        
        # Execute search
        results = self._execute_search(
            sanitized_query,
            max_results=validated.max_results,
            filters=validated.filters,
            sort_by=validated.sort_by
        )
        
        return {
            "success": True,
            "query": validated.query,
            "sanitized_query": sanitized_query,
            "results": results,
            "validation": {
                "passed": True,
                "details": "All validations passed"
            }
        }
        
    except ValidationError as e:
        return {
            "success": False,
            "error": "Validation failed",
            "validation_errors": e.errors(),
            "original_query": query
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "original_query": query
        }

@tool
def sanitize_input(input_text: str, max_length: int = 1000) -> str:
    """
    Sanitize user input for safe processing
    
    Args:
        input_text: Raw input text
        max_length: Maximum allowed length
    
    Returns:
        Sanitized text
    """
    # Remove potentially harmful content
    sanitized = re.sub(r'[<>{}]', '', input_text)
    
    # Limit length
    if len(sanitized) > max_length:
        sanitized = sanitized[:max_length] + "... [truncated]"
    
    # Remove excessive whitespace
    sanitized = re.sub(r'\s+', ' ', sanitized).strip()
    
    return sanitized
```

### 5. Caching and Optimization Tools

Tools that implement intelligent caching and optimization strategies.

```python
from langchain_core.tools import tool
from functools import lru_cache
from typing import Tuple, Dict, Any
import time
import hashlib

class ResearchCache:
    def __init__(self, max_size: int = 100, ttl: int = 3600):
        self.max_size = max_size
        self.ttl = ttl
        self.cache: Dict[str, Tuple[Any, float]] = {}
    
    def _generate_key(self, query: str, **kwargs) -> str:
        """Generate cache key"""
        key_data = f"{query}_{str(kwargs)}"
        return hashlib.md5(key_data.encode()).hexdigest()
    
    def get(self, query: str, **kwargs) -> Optional[Dict[str, Any]]:
        """Get cached result"""
        key = self._generate_key(query, **kwargs)
        
        if key in self.cache:
            result, timestamp = self.cache[key]
            
            # Check TTL
            if time.time() - timestamp < self.ttl:
                return {
                    "cached": True,
                    "result": result,
                    "age_seconds": int(time.time() - timestamp)
                }
            else:
                # Remove expired cache
                del self.cache[key]
        
        return None
    
    def set(self, query: str, result: Any, **kwargs):
        """Set cache result"""
        if len(self.cache) >= self.max_size:
            # Remove oldest entry
            oldest_key = min(self.cache.keys(), key=lambda k: self.cache[k][1])
            del self.cache[oldest_key]
        
        key = self._generate_key(query, **kwargs)
        self.cache[key] = (result, time.time())

@tool
def cached_search(query: str, **kwargs) -> Dict[str, Any]:
    """
    Search with intelligent caching
    
    Args:
        query: Search query
        **kwargs: Search parameters
    
    Returns:
        Search results with cache information
    """
    cache = ResearchCache(max_size=50, ttl=1800)
    
    # Check cache first
    cached = cache.get(query, **kwargs)
    if cached:
        return cached
    
    # Execute search
    result = self._execute_search(query, **kwargs)
    
    # Cache result
    cache.set(query, result, **kwargs)
    
    return {
        "cached": False,
        "result": result,
        "cache_size": len(cache.cache)
    }

@tool
def optimized_search(query: str, **kwargs) -> Dict[str, Any]:
    """
    Search with optimization strategies
    
    Args:
        query: Search query
        **kwargs: Search parameters
    
    Returns:
        Optimized search results
    """
    # Step 1: Query optimization
    optimized_query = self._optimize_query(query)
    
    # Step 2: Smart caching
    cached = cached_search(optimized_query, **kwargs)
    if cached.get("cached"):
        return cached
    
    # Step 3: Result processing
    raw_results = cached["result"]
    processed_results = self._process_results(raw_results)
    
    return {
        "optimized": True,
        "original_query": query,
        "optimized_query": optimized_query,
        "results": processed_results
    }
```

## Integration Patterns

### 1. Tool Composition

Combine multiple tools to create complex workflows.

```python
@tool
def comprehensive_analysis(
    paper_id: str,
    analysis_depth: str = "full"
) -> Dict[str, Any]:
    """
    Comprehensive paper analysis using multiple tools
    
    Args:
        paper_id: Paper identifier
        analysis_depth: Analysis depth - 'light', 'standard', 'full'
    
    Returns:
        Comprehensive analysis results
    """
    # Validate input
    sanitized_id = sanitize_input(paper_id)
    
    # Get basic metadata
    metadata = get_paper_metadata(sanitized_id)
    
    # Get abstract
    abstract = get_paper_abstract(sanitized_id)
    
    # Get citations
    citations = get_paper_citations(sanitized_id)
    
    # Get related papers
    related = get_related_papers(sanitized_id)
    
    # Perform sentiment analysis if full depth
    if analysis_depth == "full":
        sentiment = analyze_paper_sentiment(abstract)
    else:
        sentiment = None
    
    return {
        "metadata": metadata,
        "abstract": abstract,
        "citations": citations,
        "related_papers": related,
        "sentiment_analysis": sentiment,
        "analysis_depth": analysis_depth
    }
```

### 2. Error Recovery Tools

Tools that handle failures and provide recovery options.

```python
@tool
def resilient_search(query: str, max_retries: int = 3) -> Dict[str, Any]:
    """
    Search with error recovery and retry logic
    
    Args:
        query: Search query
        max_retries: Maximum retry attempts
    
    Returns:
        Search results or error information
    """
    import time
    
    for attempt in range(max_retries):
        try:
            # Try primary search method
            result = self._primary_search(query)
            return {
                "success": True,
                "result": result,
                "attempts": attempt + 1
            }
        except ConnectionError as e:
            # Log connection error
            if attempt == max_retries - 1:
                return {
                    "success": False,
                    "error": "Connection failed after retries",
                    "original_error": str(e),
                    "attempts": attempt + 1
                }
            
            # Wait before retry
            time.sleep(2 ** attempt)
            continue
        except ValueError as e:
            # Handle validation errors
            return {
                "success": False,
                "error": "Validation error",
                "original_error": str(e),
                "attempts": attempt + 1
            }
        except Exception as e:
            # Handle unexpected errors
            if attempt == max_retries - 1:
                return {
                    "success": False,
                    "error": "Unexpected error after retries",
                    "original_error": str(e),
                    "attempts": attempt + 1
                }
            
            time.sleep(1)
            continue
```

### 3. Progressive Enhancement Tools

Tools that provide basic results quickly and enhance them progressively.

```python
@tool
def progressive_paper_analysis(paper_id: str) -> Dict[str, Any]:
    """
    Progressive paper analysis with immediate and enhanced results
    
    Args:
        paper_id: Paper identifier
    
    Returns:
        Analysis results with progressive enhancement
    """
    import asyncio
    
    async def get_basic_info() -> Dict[str, Any]:
        """Get basic paper information"""
        return {
            "metadata": await self._get_basic_metadata(paper_id),
            "abstract_preview": await self._get_abstract_preview(paper_id),
            "publication_date": await self._get_publication_date(paper_id)
        }
    
    async def get_enhanced_info() -> Dict[str, Any]:
        """Get enhanced paper information"""
        return {
            "full_abstract": await self._get_full_abstract(paper_id),
            "citations": await self._get_citations(paper_id),
            "related_works": await self._get_related_works(paper_id),
            "sentiment": await self._analyze_sentiment(paper_id)
        }
    
    # Get basic info immediately
    basic_info = asyncio.run(get_basic_info())
    
    # Start enhanced info in background
    enhanced_task = asyncio.create_task(get_enhanced_info())
    
    # Return basic results immediately
    results = {
        "status": "basic_results_available",
        "basic_info": basic_info,
        "enhanced_info": None
    }
    
    # Wait for enhanced results (with timeout)
    try:
        enhanced_info = asyncio.run(asyncio.wait_for(enhanced_task, timeout=5))
        results["enhanced_info"] = enhanced_info
        results["status"] = "enhanced_results_available"
    except asyncio.TimeoutError:
        results["enhanced_info"] = {"status": "pending"}
        results["status"] = "basic_results_only"
    
    return results
```

## Best Practices

### 1. Tool Design Principles

1. **Single Responsibility**
   ```python
   @tool
   def search_arxiv(query: str) -> str:
       """Search arXiv - single responsibility"""
       # Implementation
   
   @tool
   def analyze_paper(paper_id: str) -> dict:
       """Analyze paper - single responsibility"""
       # Implementation
   ```

2. **Clear Error Handling**
   ```python
   @tool
   def robust_search(query: str) -> Dict[str, Any]:
       """Search with clear error handling"""
       try:
           result = external_search(query)
           return {"success": True, "result": result}
       except Exception as e:
           return {"success": False, "error": str(e)}
   ```

3. **Performance Awareness**
   ```python
   @tool
   def optimized_search(query: str) -> Dict[str, Any]:
       """Search with performance considerations"""
       if len(query) < 3:
           return {"error": "Query too short for optimization"}
       # Implementation
   ```

### 2. Testing Custom Tools

```python
def test_custom_tools():
    """Test custom tool implementations"""
    
    # Test multi-modal tool
    image = Image.new('RGB', (100, 100), color = 'red')
    result = multi_modal_analyze(image, analysis_type="image")
    assert result["type"] == "image"
    
    # Test stateful tool
    stateful_tool = StatefulResearchTool()
    result1 = stateful_tool._run("test query")
    result2 = stateful_tool._run("test query")
    assert result2["cached"] == True
    
    # Test validation tool
    valid = validated_search("valid query")
    assert valid["success"] == True
    
    invalid = validated_search("")
    assert invalid["success"] == False
```

### 3. Documentation Standards

```python
@tool
def search_papers(
    query: str,
    max_results: int = 10,
    filters: dict | None = None,
    sort_by: str = "relevance"
) -> List[dict]:
    """
    Search for academic papers with advanced filtering
    
    Args:
        query: Search query string (required)
        max_results: Maximum number of results to return (1-100, default: 10)
        filters: Dictionary of filters (e.g., {"year": "2024", "category": "cs.AI"})
        sort_by: Sorting method - 'relevance', 'date', 'citation_count' (default: 'relevance')
    
    Returns:
        List of paper dictionaries with metadata, abstract, and source information
    
    Example:
        >>> results = search_papers("machine learning", max_results=5)
        >>> len(results)
        5
    
    Raises:
        ValueError: If query is empty or max_results is out of range
        ConnectionError: If external API is unavailable
    """
    # Implementation
```

## Integration with LangGraph

### 1. ToolNode Integration

```python
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode
from typing import TypedDict, List

class ToolState(TypedDict):
    query: str
    results: List[dict]
    error: str | None

# Create custom tools
custom_tools = [
    validated_search,
    multi_modal_analyze,
    cached_search,
    progressive_paper_analysis
]

# Create ToolNode
tool_node = ToolNode(custom_tools)

# Build graph
graph = StateGraph(ToolState)
graph.add_node("tool", tool_node)
graph.set_entry_point("tool")
graph.add_edge("tool", END)
```

### 2. Custom Node Integration

```python
from typing import TypedDict

class CustomToolState(TypedDict):
    query: str
    analysis_results: dict | None
    processing_steps: List[str]

@tool
def analyze_with_context(paper_id: str, context: str) -> dict:
    """Analyze paper with contextual information"""
    # Implementation
    return {"analysis": "Contextual analysis result"}

@tool
def get_related_context(query: str) -> str:
    """Get context for analysis"""
    # Implementation
    return "Related context information"

# Custom node using tools
def analysis_node(state: CustomToolState) -> CustomToolState:
    """Node that uses custom tools"""
    # Get context
    context = get_related_context(state["query"])
    
    # Perform analysis
    analysis = analyze_with_context(state["query"], context)
    
    return {
        "query": state["query"],
        "analysis_results": analysis,
        "processing_steps": ["context_retrieval", "analysis_execution"]
    }
```

## Performance Considerations

### 1. Tool Caching Strategies

```python
class ToolCache:
    def __init__(self):
        self.cache = {}
        self.hits = 0
        self.misses = 0
    
    def get(self, tool_name: str, args: tuple) -> Optional[Any]:
        """Get cached result"""
        key = f"{tool_name}_{str(args)}"
        if key in self.cache:
            self.hits += 1
            return self.cache[key]
        self.misses += 1
        return None
    
    def set(self, tool_name: str, args: tuple, result: Any):
        """Set cache result"""
        key = f"{tool_name}_{str(args)}"
        self.cache[key] = result
    
    def stats(self) -> dict:
        """Get cache statistics"""
        total = self.hits + self.misses
        return {
            "hits": self.hits,
            "misses": self.misses,
            "hit_rate": self.hits / total if total > 0 else 0
        }
```

### 2. Tool Execution Monitoring

```python
import time
from typing import Callable
from functools import wraps

def monitor_tool_execution(func: Callable) -> Callable:
    """Decorator to monitor tool execution"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        
        try:
            result = func(*args, **kwargs)
            execution_time = time.time() - start_time
            
            # Log execution
            print(f"Tool {func.__name__} executed in {execution_time:.3f}s")
            
            return {"success": True, "result": result, "execution_time": execution_time}
            
        except Exception as e:
            execution_time = time.time() - start_time
            print(f"Tool {func.__name__} failed in {execution_time:.3f}s")
            return {"success": False, "error": str(e), "execution_time": execution_time}
    
    return wrapper

@tool
def monitored_search(query: str) -> str:
    """Search with execution monitoring"""
    # Implementation
    return "Search results"

# Apply monitoring
monitored_search = monitor_tool_execution(monitored_search)
```

## Security Considerations

### 1. Input Validation

```python
def validate_tool_input(tool_name: str, input_data: Any) -> bool:
    """Validate tool input for security"""
    # Check for malicious content
    if isinstance(input_data, str):
        if re.search(r'[<>{}]', input_data):
            return False
    
    # Check size limits
    if isinstance(input_data, (str, bytes)) and len(input_data) > 10000:
        return False
    
    # Check allowed operations
    allowed_tools = ["search", "analyze", "validate"]
    if tool_name not in allowed_tools:
        return False
    
    return True
```

### 2. Safe Tool Execution

```python
def safe_tool_execution(tool_func: Callable, *args, **kwargs) -> dict:
    """Execute tool safely with sandboxing"""
    import traceback
    
    try:
        # Validate inputs
        if not validate_tool_input(tool_func.__name__, args[0] if args else kwargs):
            return {"success": False, "error": "Invalid input detected"}
        
        # Execute tool
        result = tool_func(*args, **kwargs)
        
        return {"success": True, "result": result}
        
    except Exception as e:
        # Capture error safely
        error_info = traceback.format_exc()
        
        return {"success": False, "error": str(e), "traceback": error_info}
```

## Conclusion

Creating custom tools for LangGraph agents requires careful consideration of functionality, performance, error handling, and security. By following the patterns and best practices outlined in this guide, you can build powerful, reliable tools that extend your agents' capabilities.

Remember to:
- Design tools with single responsibility
- Implement proper error handling and validation
- Consider performance and caching strategies
- Monitor tool execution and performance
- Prioritize security in tool design
- Write comprehensive tests for all custom tools
- Document tools thoroughly for maintainability

With these patterns, you can create sophisticated tools that enable your LangGraph agents to handle complex tasks and integrate seamlessly with external systems.