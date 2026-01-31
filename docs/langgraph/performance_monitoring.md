# LangGraph Performance Monitoring Guide

This guide covers monitoring and performance optimization techniques for LangGraph applications, including metrics collection, profiling, and optimization strategies.

## Overview

Performance monitoring is crucial for LangGraph applications to ensure responsiveness, identify bottlenecks, and maintain optimal resource utilization. This guide provides comprehensive strategies for monitoring LangGraph workflows.

## Key Performance Metrics

### 1. Execution Time Metrics
- **Node Execution Time**: Time taken by each node to complete
- **Total Graph Execution Time**: End-to-end processing time
- **Average Node Time**: Mean execution time across all nodes
- **P95/P99 Latency**: 95th and 99th percentile execution times

### 2. Resource Utilization
- **Memory Usage**: Memory consumption per node and overall
- **CPU Usage**: CPU utilization during graph execution
- **Network I/O**: Data transfer between nodes and external services
- **LLM Token Usage**: Number of tokens processed by language models

### 3. State Management Metrics
- **State Size**: Memory footprint of the state dictionary
- **State Access Patterns**: Frequency of state reads/writes
- **Serialization Time**: Time to serialize/deserialize state
- **State Compression Ratio**: Effectiveness of state compression

### 4. Error and Retry Metrics
- **Error Rate**: Percentage of failed node executions
- **Retry Count**: Number of retries per node
- **Recovery Time**: Time to recover from failures
- **Failure Patterns**: Common failure scenarios

## Monitoring Implementation

### 1. Built-in LangGraph Monitoring

LangGraph provides basic monitoring capabilities through its execution context:

```python
from langgraph.graph import StateGraph
from langgraph.monitor import Monitor

class ResearchState(TypedDict):
    query: str
    papers: list
    result: str | None

# Create a monitor instance
monitor = Monitor()

# Create graph with monitoring
graph = StateGraph(ResearchState)
graph.add_monitor(monitor)

# Monitor execution
execution = graph.execute(initial_state)
metrics = monitor.get_metrics()
```

### 2. Custom Metrics Collection

Implement custom metrics collection using decorators or middleware:

```python
import time
from functools import wraps
from typing import Callable, Dict, Any

class PerformanceMonitor:
    def __init__(self):
        self.metrics = {
            "node_execution_times": {},
            "memory_usage": {},
            "error_counts": {},
            "retry_counts": {}
        }
    
    def time_node(self, node_name: str):
        def decorator(func: Callable):
            @wraps(func)
            def wrapper(state: Dict[str, Any], *args, **kwargs):
                start_time = time.time()
                try:
                    result = func(state, *args, **kwargs)
                    execution_time = time.time() - start_time
                    self.metrics["node_execution_times"][node_name] = execution_time
                    return result
                except Exception as e:
                    self.metrics["error_counts"][node_name] = self.metrics["error_counts"].get(node_name, 0) + 1
                    raise
            return wrapper
        return decorator
```

### 3. Integration with External Monitoring

#### Prometheus Integration
```python
from prometheus_client import Histogram, Counter, Gauge

NODE_EXECUTION_TIME = Histogram('langgraph_node_execution_time_seconds', 'Execution time of LangGraph nodes')
NODE_ERROR_COUNT = Counter('langgraph_node_error_count', 'Number of errors per node')
STATE_SIZE_GAUGE = Gauge('langgraph_state_size_bytes', 'Size of LangGraph state')

class PrometheusMonitor:
    def __init__(self):
        pass
    
    def track_node_execution(self, node_name: str, execution_time: float):
        NODE_EXECUTION_TIME.labels(node=node_name).observe(execution_time)
    
    def track_error(self, node_name: str):
        NODE_ERROR_COUNT.labels(node=node_name).inc()
    
    def track_state_size(self, state_size: int):
        STATE_SIZE_GAUGE.set(state_size)
```

#### OpenTelemetry Integration
```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.jaeger.thrift import JaegerExporter

tracer_provider = TracerProvider()
span_processor = BatchSpanProcessor(JaegerExporter(agent_host_name="localhost", agent_port=6831))
tracer_provider.add_span_processor(span_processor)
trace.set_tracer_provider(tracer_provider)

tracer = trace.get_tracer(__name__)

def trace_node_execution(node_name: str):
    def decorator(func: Callable):
        @wraps(func)
        def wrapper(state: Dict[str, Any], *args, **kwargs):
            with tracer.start_as_current_span(f"langgraph.{node_name}") as span:
                start_time = time.time()
                try:
                    result = func(state, *args, **kwargs)
                    execution_time = time.time() - start_time
                    span.set_attribute("execution_time", execution_time)
                    return result
                except Exception as e:
                    span.set_attribute("error", str(e))
                    raise
        return wrapper
    return decorator
```

## Performance Optimization Strategies

### 1. State Management Optimization

#### State Compression
```python
import pickle
import zlib
from typing import TypedDict

class CompressedState(TypedDict):
    compressed_data: bytes
    metadata: dict

class StateCompressor:
    def __init__(self, compression_level: int = 6):
        self.compression_level = compression_level
    
    def compress_state(self, state: dict) -> CompressedState:
        serialized = pickle.dumps(state)
        compressed = zlib.compress(serialized, level=self.compression_level)
        return {
            "compressed_data": compressed,
            "metadata": {
                "original_size": len(serialized),
                "compressed_size": len(compressed),
                "compression_ratio": len(serialized) / len(compressed)
            }
        }
    
    def decompress_state(self, compressed_state: CompressedState) -> dict:
        decompressed = zlib.decompress(compressed_state["compressed_data"])
        return pickle.loads(decompressed)
```

#### Selective State Storage
```python
from typing import TypedDict, Optional

class OptimizedState(TypedDict):
    essential_data: dict
    derived_data: Optional[dict]

class StateOptimizer:
    def __init__(self):
        self.essential_fields = ["query", "papers", "classification"]
        self.derived_fields = ["formatted_results", "cached_responses"]
    
    def optimize_state(self, state: dict) -> OptimizedState:
        essential = {k: v for k, v in state.items() if k in self.essential_fields}
        derived = {k: v for k, v in state.items() if k in self.derived_fields}
        
        return {
            "essential_data": essential,
            "derived_data": derived if derived else None
        }
    
    def restore_state(self, optimized_state: OptimizedState) -> dict:
        state = optimized_state["essential_data"].copy()
        if optimized_state["derived_data"]:
            state.update(optimized_state["derived_data"])
        return state
```

### 2. Node Execution Optimization

#### Caching Strategy
```python
from functools import lru_cache
from typing import Callable, Any

class NodeCache:
    def __init__(self, max_size: int = 128):
        self.cache = lru_cache(maxsize=max_size)(self._cached_node)
    
    def _cached_node(self, node_name: str, state_hash: str, *args) -> Any:
        # Actual node execution logic
        pass
    
    def execute_with_cache(self, node_name: str, state: dict, *args) -> Any:
        state_hash = hash(frozenset(state.items()))
        return self.cache(node_name, state_hash, *args)
```

#### Parallel Execution
```python
import asyncio
from typing import List, Dict, Any

class ParallelExecutor:
    def __init__(self):
        self.semaphore = asyncio.Semaphore(5)  # Limit concurrent executions
    
    async def execute_nodes_in_parallel(
        self, 
        nodes: List[Callable], 
        state: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        async def execute_node(node: Callable):
            async with self.semaphore:
                return node(state)
        
        tasks = [execute_node(node) for node in nodes]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        return results
```

### 3. Memory Management

#### Memory Profiling
```python
import memory_profiler
from typing import Dict, Any

class MemoryMonitor:
    def __init__(self):
        self.memory_usage = {}
    
    def profile_node(self, node_name: str, state: Dict[str, Any]) -> Dict[str, Any]:
        mem_before = memory_profiler.memory_usage()[0]
        
        # Execute node
        result = node_function(state)
        
        mem_after = memory_profiler.memory_usage()[0]
        mem_delta = mem_after - mem_before
        
        self.memory_usage[node_name] = {
            "before": mem_before,
            "after": mem_after,
            "delta": mem_delta,
            "peak": max(mem_before, mem_after)
        }
        
        return result
```

#### Memory Cleanup
```python
import gc
from typing import Dict, Any

class MemoryManager:
    def __init__(self):
        self.cleanup_threshold = 100 * 1024 * 1024  # 100MB
        self.last_cleanup = time.time()
    
    def cleanup_if_needed(self, current_memory: int):
        if current_memory > self.cleanup_threshold:
            if time.time() - self.last_cleanup > 60:  # Cleanup every 60 seconds
                self.perform_cleanup()
                self.last_cleanup = time.time()
    
    def perform_cleanup(self):
        gc.collect()
        # Additional cleanup logic
        # Clear caches, close connections, etc.
```

## Performance Monitoring Dashboard

### Grafana Dashboard Configuration

```yaml
# dashboard.yaml
dashboard:
  title: "LangGraph Performance Monitoring"
  panels:
    - title: "Node Execution Times"
      type: graph
      targets:
        - expr: langgraph_node_execution_time_seconds_sum
          legend: "{{node}} - Total Time"
        - expr: langgraph_node_execution_time_seconds_count
          legend: "{{node}} - Execution Count"
    - title: "Memory Usage"
      type: graph
      targets:
        - expr: langgraph_state_size_bytes
          legend: "State Size"
        - expr: process_resident_memory_bytes
          legend: "Process Memory"
    - title: "Error Rates"
      type: graph
      targets:
        - expr: rate(langgraph_node_error_count_total[5m])
          legend: "Error Rate"
    - title: "LLM Token Usage"
      type: graph
      targets:
        - expr: langgraph_llm_tokens_total
          legend: "Total Tokens"
```

### Alerting Rules

```yaml
# alerting_rules.yaml
groups:
  - name: langgraph.rules
    rules:
      - alert: HighNodeExecutionTime
        expr: langgraph_node_execution_time_seconds_avg > 30
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Node {{ $labels.node }} execution time is too high"
          description: "Average execution time for {{ $labels.node }} is {{ $value }} seconds"
      
      - alert: HighErrorRate
        expr: rate(langgraph_node_error_count_total[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate for node {{ $labels.node }}"
          description: "Error rate for {{ $labels.node }} is {{ $value }} errors per second"
      
      - alert: HighMemoryUsage
        expr: langgraph_state_size_bytes > 500000000
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "State size has exceeded 500MB"
```

## Best Practices

### 1. Monitoring Setup
- **Start Simple**: Begin with basic metrics and expand as needed
- **Centralized Collection**: Use a centralized monitoring system
- **Consistent Naming**: Use consistent naming conventions for metrics
- **Alert Thresholds**: Set appropriate alert thresholds based on baselines

### 2. Performance Testing
- **Load Testing**: Test with varying loads to identify bottlenecks
- **Stress Testing**: Push the system to its limits to find breaking points
- **Regression Testing**: Ensure performance doesn't degrade over time
- **Benchmarking**: Establish performance baselines for comparison

### 3. Optimization Workflow
1. **Monitor**: Collect comprehensive metrics
2. **Analyze**: Identify bottlenecks and patterns
3. **Optimize**: Implement targeted improvements
4. **Validate**: Verify improvements with testing
5. **Monitor**: Continue monitoring to ensure sustained performance

### 4. Common Pitfalls to Avoid
- **Over-monitoring**: Don't collect metrics that aren't actionable
- **Ignoring Context**: Consider the context when analyzing metrics
- **Premature Optimization**: Don't optimize before understanding the problem
- **Neglecting Maintenance**: Regularly review and update monitoring setup

## Advanced Topics

### 1. Distributed Tracing

For distributed LangGraph applications:

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.jaeger.thrift import JaegerExporter

# Configure distributed tracing
provider = TracerProvider()
processor = BatchSpanProcessor(JaegerExporter(agent_host_name="jaeger", agent_port=6831))
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)

# Use in LangGraph nodes
tracer = trace.get_tracer(__name__)

def distributed_node(state: Dict[str, Any]):
    with tracer.start_as_current_span("distributed_node") as span:
        # Node logic
        span.set_attribute("node_type", "distributed")
        return updated_state
```

### 2. Performance Regression Testing

```python
import pytest
import time
from typing import Callable, Dict, Any

class PerformanceTest:
    def __init__(self, baseline_metrics: dict):
        self.baseline_metrics = baseline_metrics
        self.tolerance = 1.2  # 20% tolerance
    
    def test_node_performance(self, node: Callable, state: Dict[str, Any]):
        # Warm up
        for _ in range(3):
            node(state)
        
        # Measure performance
        execution_times = []
        for _ in range(10):
            start_time = time.time()
            node(state)
            execution_times.append(time.time() - start_time)
        
        avg_time = sum(execution_times) / len(execution_times)
        baseline_time = self.baseline_metrics.get("avg_execution_time", float("inf"))
        
        assert avg_time <= baseline_time * self.tolerance, \
            f"Node performance degraded: {avg_time:.2f}s vs baseline {baseline_time:.2f}s"
```

### 3. Automated Performance Optimization

```python
import statistics
from typing import Dict, Any, List

class PerformanceOptimizer:
    def __init__(self, metrics_collector):
        self.metrics_collector = metrics_collector
        self.optimization_history = []
    
    def analyze_performance(self, node_name: str) -> Dict[str, Any]:
        metrics = self.metrics_collector.get_node_metrics(node_name)
        
        analysis = {
            "avg_execution_time": statistics.mean(metrics["execution_times"]),
            "std_deviation": statistics.stdev(metrics["execution_times"]),
            "error_rate": metrics["error_count"] / metrics["execution_count"],
            "memory_usage": statistics.mean(metrics["memory_usage"])
        }
        
        return analysis
    
    def suggest_optimizations(self, analysis: Dict[str, Any]) -> List[str]:
        suggestions = []
        
        if analysis["avg_execution_time"] > 10:  # 10 seconds threshold
            suggestions.append("Consider implementing caching for this node")
        
        if analysis["error_rate"] > 0.1:
            suggestions.append("Review error handling and retry logic")
        
        if analysis["memory_usage"] > 100 * 1024 * 1024:  # 100MB
            suggestions.append("Consider state compression or memory optimization")
        
        return suggestions
```

## Conclusion

Effective performance monitoring is essential for building robust LangGraph applications. By implementing comprehensive monitoring, following optimization best practices, and continuously analyzing performance data, you can ensure your LangGraph workflows remain efficient and reliable.

Remember to:
- Start with basic monitoring and expand as needed
- Focus on actionable metrics
- Regularly review and optimize performance
- Use automated testing to prevent regression
- Consider the specific requirements of your use case

This guide provides a foundation for LangGraph performance monitoring, but the specific implementation should be tailored to your application's needs and scale.