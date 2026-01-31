# LangGraph Troubleshooting Guide

## Overview

This guide provides solutions to common issues encountered when working with LangGraph applications. It complements the debugging guide by focusing on specific problems and their resolutions rather than general debugging techniques.

---

## Quick Reference

### Common Error Messages and Solutions

| Error Message | Likely Cause | Solution |
|---------------|--------------|----------|
| `NodeNotFoundError` | Node not in graph | Verify node exists and is properly added |
| `StateMutationError` | State not properly returned | Ensure node returns modified state |
| `ConditionalEdgeError` | Invalid conditional function | Check conditional returns boolean |
| `GraphExecutionError` | Graph compilation issues | Verify all nodes and edges are properly configured |

---

## Common Issues and Solutions

### 1. Graph Not Executing

#### Problem
Your LangGraph graph doesn't execute or appears to hang.

#### Solutions

```python
# Check 1: Verify graph structure
def verify_graph_structure(graph: StateGraph) -> None:
    """Verify graph has nodes, edges, and entry point"""
    if not graph.nodes:
        raise ValueError("Graph has no nodes. Add nodes with graph.add_node()")
    
    if not graph.edges:
        raise ValueError("Graph has no edges. Add edges with graph.add_edge()")
    
    if not graph.entry_point:
        raise ValueError("Graph has no entry point. Set with graph.set_entry_point()")

# Check 2: Verify node execution
class NodeExecutionDebugger:
    def __init__(self, graph: StateGraph):
        self.graph = graph
        self.execution_log = []
    
    def debug_execution(self, initial_state: State) -> None:
        """Debug node execution step by step"""
        current_state = initial_state
        
        while True:
            current_node = self.get_current_node(current_state)
            
            if current_node is None:
                print("No valid node found. Check graph structure and conditions.")
                break
            
            print(f"Executing node: {current_node}")
            
            try:
                current_state = self.graph.compile().invoke(current_state)
                self.execution_log.append(current_node)
            except Exception as e:
                print(f"Error executing {current_node}: {e}")
                break
            
            if self.is_graph_complete(current_state):
                print("Graph execution completed successfully")
                break
```

### 2. State Not Updating

#### Problem
State modifications in nodes don't persist or appear to be lost.

#### Solutions

```python
# Check 1: Verify state mutation
class StateMutationValidator:
    def __init__(self):
        self.required_fields = ["input", "context", "metadata"]
    
    def validate_state_mutation(self, old_state: State, new_state: State, node_name: str) -> bool:
        """Validate that state has been properly mutated"""
        # Check if state is actually a dictionary
        if not isinstance(new_state, dict):
            print(f"Error in {node_name}: Node should return dictionary state")
            return False
        
        # Check for required fields
        for field in self.required_fields:
            if field not in new_state:
                print(f"Warning in {node_name}: Missing required field '{field}'")
                return False
        
        # Check if state actually changed
        if old_state == new_state:
            print(f"Warning in {node_node}: State did not change after execution")
            return False
        
        return True

# Check 2: Debug state return values
def debug_state_return(node_function: Callable, input_state: State) -> None:
    """Debug state return values from node"""
    try:
        result = node_function(input_state)
        
        print("Node returned:")
        print(json.dumps(result, indent=2))
        
        # Check if result is valid state
        if not isinstance(result, dict):
            print("Error: Node should return dictionary state")
        
    except Exception as e:
        print(f"Node raised exception: {e}")
```

### 3. Conditional Edges Not Working

#### Problem
Conditional edges don't execute as expected or conditions always return False.

#### Solutions

```python
# Check 1: Verify conditional functions
class ConditionalValidator:
    def __init__(self):
        self.test_state = {
            "input": "test_value",
            "context": "test_context",
            "metadata": {}
        }
    
    def validate_condition(self, condition: Callable[[State], bool], description: str = "") -> bool:
        """Validate conditional function"""
        try:
            result = condition(self.test_state)
            
            if not isinstance(result, bool):
                print(f"Error: Condition '{description}' should return boolean, got {type(result).__name__}")
                return False
            
            print(f"Condition '{description}' test result: {result}")
            return True
            
        except Exception as e:
            print(f"Error testing condition '{description}': {e}")
            return False

# Check 2: Debug conditional edge flow
def debug_conditional_flow(graph: StateGraph, start_node: str) -> None:
    """Debug conditional edge flow"""
    current_node = start_node
    test_state = {
        "input": "test_input",
        "context": "test_context",
        "metadata": {}
    }
    
    while True:
        print(f"Current node: {current_node}")
        
        # Get possible edges
        edges = graph.edges.get(current_node, [])
        
        if not edges:
            print("No outgoing edges from current node")
            break
        
        # Test each edge condition
        for edge in edges:
            if len(edge) > 2 and edge[2]:  # Conditional edge
                condition = edge[2]
                try:
                    condition_result = condition(test_state)
                    print(f"Edge to {edge[0]} condition result: {condition_result}")
                except Exception as e:
                    print(f"Error testing edge condition: {e}")
            else:
                print(f"Unconditional edge to {edge[0]}")
        
        # Move to next node (for testing purposes)
        if edges:
            current_node = edges[0][0]
        else:
            break
```

### 4. Performance Issues

#### Problem
Graph execution is slow or consumes too much memory.

#### Solutions

```python
# Check 1: Identify bottlenecks
class PerformanceDebugger:
    def __init__(self):
        self.metrics = {
            "execution_times": {},
            "memory_usage": {},
            "message_counts": {}
        }
        self.start_time = time.time()
    
    def record_node_execution(self, node_name: str, duration: float) -> None:
        """Record node execution time"""
        if node_name not in self.metrics["execution_times"]:
            self.metrics["execution_times"][node_name] = []
        self.metrics["execution_times"][node_name].append(duration)
    
    
    def analyze_bottlenecks(self) -> dict:
        """Analyze performance bottlenecks"""
        total_time = time.time() - self.start_time
        
        # Find slowest nodes
        node_stats = {}
        for node, times in self.metrics["execution_times"].items():
            node_stats[node] = {
                "average_time": sum(times) / len(times),
                "total_time": sum(times),
                "execution_count": len(times),
                "percentage": (sum(times) / total_time) * 100
            }
        
        # Sort by total time
        sorted_nodes = sorted(
            node_stats.items(),
            key=lambda x: x[1]["total_time"],
            reverse=True
        )
        
        return {
            "total_execution_time": total_time,
            "bottleneck_nodes": sorted_nodes[:5],  # Top 5 bottlenecks
            "memory_usage": self.metrics["memory_usage"]
        }

# Check 2: Memory optimization
def debug_memory_issues(graph: StateGraph, initial_state: State) -> None:
    """Debug memory issues in graph execution"""
    import tracemalloc
    
    tracemalloc.start()
    
    try:
        # Execute graph
        result = graph.compile().invoke(initial_state)
        
    finally:
        current, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        
        print(f"Current memory usage: {current / 10**6:.2f}MB")
        print(f"Peak memory usage: {peak / 10**6:.2f}MB")
        
        # Memory optimization suggestions
        if peak > 100 * 10**6:  # 100MB threshold
            print("Memory usage is high. Consider:")
            print("- Using state compression techniques")
            print("- Avoiding large data in state")
            print("- Using database for large datasets")
```

### 5. Integration Issues

#### Problem
Problems integrating LangGraph with external services or APIs.

#### Solutions

```python
# Check 1: API integration debugging
class APIIntegrationDebugger:
    def __init__(self):
        self.api_errors = []
        self.request_counts = {}
    
    def debug_api_call(self, api_function: Callable, *args, **kwargs) -> Any:
        """Debug API call with error handling"""
        try:
            # Record request
            api_name = api_function.__name__
            self.request_counts[api_name] = self.request_counts.get(api_name, 0) + 1
            
            # Execute API call
            result = api_function(*args, **kwargs)
            
            return result
            
        except Exception as e:
            # Record error
            self.api_errors.append({
                "api": api_function.__name__,
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            })
            
            print(f"API Error in {api_function.__name__}: {e}")
            
            # Common API error handling
            if "timeout" in str(e).lower():
                print("Suggestion: Increase timeout or check network connectivity")
            elif "authentication" in str(e).lower():
                print("Suggestion: Verify API keys and authentication")
            elif "rate limit" in str(e).lower():
                print("Suggestion: Implement rate limiting or exponential backoff")
            
            return None

# Check 2: Database integration debugging
def debug_database_integration(db_function: Callable, *args, **kwargs) -> Any:
    """Debug database integration issues"""
    try:
        # Execute database operation
        result = db_function(*args, **kwargs)
        
        return result
        
    except Exception as e:
        print(f"Database Error: {e}")
        
        # Common database error handling
        if "connection" in str(e).lower():
            print("Suggestion: Check database connection string and credentials")
        elif "timeout" in str(e).lower():
            print("Suggestion: Check database server status and network")
        elif "duplicate key" in str(e).lower():
            print("Suggestion: Check for existing records or use upsert operations")
        
        return None
```

### 6. Error Handling Issues

#### Problem
Errors in graph execution are not properly caught or handled.

#### Solutions

```python
# Check 1: Implement robust error handling
class ErrorHandlingDebugger:
    def __init__(self):
        self.error_handlers = {}
    
    def add_error_handler(self, error_type: Type[Exception], handler: Callable) -> None:
        """Add error handler for specific exception type"""
        self.error_handlers[error_type] = handler
    
    def debug_error_handling(self, node_function: Callable, state: State) -> tuple[State, bool]:
        """Debug error handling in node"""
        try:
            result = node_function(state)
            return result, False  # No error
            
        except Exception as e:
            print(f"Error in node: {e}")
            
            # Check for specific error handlers
            error_type = type(e)
            if error_type in self.error_handlers:
                print(f"Using error handler for {error_type.__name__}")
                handler = self.error_handlers[error_type]
                return handler(state, e), True  # Error handled
            
            # Default error handling
            print("No specific error handler found. Returning original state.")
            return state, True  # Error occurred

# Check 2: Error recovery strategies
def debug_error_recovery(graph: StateGraph, initial_state: State) -> None:
    """Debug error recovery strategies"""
    try:
        # Execute graph with error recovery
        result = graph.compile().invoke(initial_state)
        print("Graph executed successfully")
        
    except Exception as e:
        print(f"Graph execution failed: {e}")
        
        # Error recovery options
        print("Error recovery options:")
        print("- Retry the operation")
        print("- Use fallback values")
        print("- Skip to next node")
        print("- Return error state")
        
        # Example: Retry mechanism
        max_retries = 3
        for attempt in range(max_retries):
            try:
                print(f"Retry attempt {attempt + 1}/{max_retries}")
                result = graph.compile().invoke(initial_state)
                print("Retry successful")
                break
            except Exception as retry_error:
                print(f"Retry {attempt + 1} failed: {retry_error}")
                if attempt == max_retries - 1:
                    print("All retries failed")
```

---

## Common Integration Issues

### 1. LangGraph with Ollama

#### Issue: Model not found or connection errors

```python
# Solution: Verify Ollama connection
def debug_ollama_connection(ollama_client) -> bool:
    """Debug Ollama connection issues"""
    try:
        models = ollama_client.list()
        print(f"Available models: {[m['name'] for m in models['models']]}")
        return True
    except Exception as e:
        print(f"Ollama connection error: {e}")
        print("Check if Ollama is running and accessible")
        print("Verify API URL and port")
        return False
```

### 2. LangGraph with LangChain

#### Issue: Chain execution errors or context issues

```python
# Solution: Debug LangChain integration
def debug_langchain_integration(chain) -> None:
    """Debug LangChain integration with LangGraph"""
    try:
        # Test chain execution
        test_input = "test prompt"
        result = chain.invoke(test_input)
        print("LangChain chain executed successfully")
        
    except Exception as e:
        print(f"LangChain error: {e}")
        print("Check chain configuration and input format")
        print("Verify model compatibility")
```

### 3. LangGraph with Databases

#### Issue: Database connection or query errors

```python
# Solution: Debug database integration
def debug_database_connection(db_client) -> bool:
    """Debug database connection issues"""
    try:
        # Test connection
        db_client.test_connection()
        print("Database connection successful")
        return True
    except Exception as e:
        print(f"Database connection error: {e}")
        print("Check connection string and credentials")
        print("Verify database server status")
        return False
```

---

## Performance Optimization Checklist

### Before Execution
- [ ] Profile graph structure and identify bottlenecks
- [ ] Optimize state size and avoid unnecessary data
- [ ] Use appropriate data types and structures
- [ ] Implement caching for expensive operations

### During Execution
- [ ] Monitor memory usage and execution times
- [ ] Use state compression for large states
- [ ] Implement batch processing when possible
- [ ] Use parallel execution for independent nodes

### After Execution
- [ ] Analyze performance metrics and logs
- [ ] Identify and fix slow-performing nodes
- [ ] Optimize database queries and API calls
- [ ] Implement proper error handling and recovery

---

## Debugging Tools and Utilities

### Quick Debug Commands

```bash
# Check graph structure
python -c "from langgraph.graph import StateGraph; print('Graph structure OK')"

# Test node execution
python -c "from my_graph import my_node; print('Node test OK')"

# Profile memory usage
python -m memory_profiler my_script.py
```

### Logging Configuration

```python
import logging

# Configure debug logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('langgraph_debug.log'),
        logging.StreamHandler()
    ]
)

# Enable debug mode in LangGraph
graph = StateGraph(State, debug=True)
```

---

## When to Seek Help

Consider seeking help if:

1. **The issue persists after trying all solutions** - You've exhausted troubleshooting options
2. **The error is cryptic or undocumented** - Error messages don't match known issues
3. **Performance is severely impacted** - Graph execution is unusably slow
4. **Integration issues with external services** - Problems with APIs, databases, or other services
5. **State management becomes complex** - State transformations are difficult to track

### Resources

- **LangGraph Documentation**: Official docs and API reference
- **Community Forums**: Stack Overflow, GitHub Discussions
- **Issue Trackers**: Report bugs and request features
- **Examples**: Study working examples and patterns

---

## Best Practices for Troubleshooting

1. **Isolate the problem** - Test individual components in isolation
2. **Reproduce consistently** - Create minimal reproducible examples
3. **Check assumptions** - Verify your understanding of the system
4. **Use systematic approach** - Follow a logical troubleshooting workflow
5. **Document findings** - Keep track of what you've tried and learned
6. **Test solutions** - Verify that fixes actually resolve the issue
7. **Monitor after fixes** - Ensure problems don't recur

Remember: Troubleshooting is a skill that improves with practice. Start with simple solutions and gradually work toward more complex ones.