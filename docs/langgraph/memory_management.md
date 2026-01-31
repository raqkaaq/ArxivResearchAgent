# Memory Management for Long-Running LangGraph Graphs

Long-running LangGraph applications require careful memory management to prevent resource leaks, ensure performance, and maintain stability over extended periods. This guide covers essential strategies for managing memory effectively in production LangGraph applications.

## Memory Challenges in LangGraph Applications

LangGraph applications face several memory-related challenges:

### State Growth
- **Accumulating state**: State objects can grow unbounded if not properly managed
- **Large response data**: LLM responses and intermediate results can consume significant memory
- **Caching effects**: Cached data, embeddings, and intermediate results accumulate over time

### Resource Leaks
- **Open connections**: Database connections, API clients, and other resources may not be properly closed
- **Event listeners**: Event handlers and callbacks may accumulate without cleanup
- **Memory fragmentation**: Frequent allocations and deallocations can lead to fragmentation

### Performance Degradation
- **Garbage collection overhead**: Large heaps increase GC pause times
- **Memory pressure**: High memory usage can trigger system-level swapping
- **Resource contention**: Multiple long-running graphs may compete for limited resources

## State Management Strategies

### 1. State Size Limiting

Implement strategies to keep state size manageable:

```python
from typing import TypedDict, Optional
from datetime import datetime, timedelta

class ManagedState(TypedDict):
    # Core data
    raw_data: str
    classification: dict | None
    results: list | None
    
    # Metadata with size limits
    history: list[tuple[datetime, str]]  # Limited to last 100 entries
    cache: dict[str, any]  # Limited to 50 items
    
    # Resource tracking
    connections: dict[str, any]
    memory_usage: dict[str, int]  # Track memory per component
```

### 2. State Pruning Strategies

Implement automatic state pruning:

```python
def prune_state(state: ManagedState, max_size: int = 1000000) -> ManagedState:
    """Prune state to keep memory usage under control."""
    
    # Remove old history entries
    if len(state.get('history', [])) > 100:
        state['history'] = state['history'][-100:]
    
    # Clear large cache entries
    if 'cache' in state:
        # Remove entries over certain size
        state['cache'] = {
            k: v for k, v in state['cache'].items()
            if sys.getsizeof(v) < 1000000
        }
        
        # Limit total number of cache entries
        if len(state['cache']) > 50:
            # Remove oldest entries
            sorted_items = sorted(state['cache'].items(), key=lambda x: x[0])
            state['cache'] = dict(sorted_items[-50:])
    
    return state
```

### 3. State Compression

Compress large state components:

```python
import zlib
import pickle
from typing import Any

def compress_data(data: Any) -> bytes:
    """Compress data using zlib."""
    serialized = pickle.dumps(data)
    compressed = zlib.compress(serialized)
    return compressed

def decompress_data(compressed: bytes) -> Any:
    """Decompress data."""
    decompressed = zlib.decompress(compressed)
    return pickle.loads(decompressed)

# Usage in state management
class CompressedState(TypedDict):
    compressed_data: bytes | None
    uncompressed_size: int
    compression_ratio: float
```

## Resource Management

### 1. Connection Pooling

Use connection pooling for database and API connections:

```python
from typing import TypedDict
import psycopg2.pool
from neo4j import GraphDatabase

class ConnectionState(TypedDict):
    postgres_pool: psycopg2.pool.ThreadedConnectionPool | None
    neo4j_driver: GraphDatabase.driver | None
    llm_client: Any  # Your LLM client
    
    # Track connection usage
    connection_usage: dict[str, int]  # Connection usage counters

# Initialize connection pool
postgres_pool = psycopg2.pool.ThreadedConnectionPool(
    minconn=1,
    maxconn=10,
    user="your_user",
    password="your_password",
    host="localhost",
    port="5432",
    database="your_db"
)

neo4j_driver = GraphDatabase.driver(
    "bolt://localhost:7687",
    auth=("neo4j", "password"),
    max_connection_lifetime=3600,  # 1 hour
    max_connection_pool_size=20
)
```

### 2. Connection Lifecycle Management

Implement proper connection lifecycle management:

```python
from typing import TypedDict, Optional
import contextlib

class ManagedConnections(TypedDict):
    postgres_conn: Optional[Any]
    neo4j_session: Optional[Any]
    llm_session: Optional[Any]

@contextlib.contextmanager
def managed_connection(state: ManagedConnections):
    """Context manager for managing connections with automatic cleanup."""
    try:
        # Acquire connections if needed
        if state['postgres_conn'] is None:
            state['postgres_conn'] = state['postgres_pool'].getconn()
        if state['neo4j_session'] is None:
            state['neo4j_session'] = state['neo4j_driver'].session()
        
        yield
        
    finally:
        # Clean up connections
        if state['postgres_conn'] is not None:
            state['postgres_pool'].putconn(state['postgres_conn'])
            state['postgres_conn'] = None
        if state['neo4j_session'] is not None:
            state['neo4j_session'].close()
            state['neo4j_session'] = None
```

### 3. Memory Monitoring

Implement memory monitoring and alerting:

```python
import psutil
import logging
from typing import Callable

class MemoryMonitor:
    def __init__(self, threshold: float = 0.8, check_interval: int = 60):
        self.threshold = threshold  # 80% threshold
        self.check_interval = check_interval
        self.logger = logging.getLogger(__name__)
        
    def check_memory(self) -> bool:
        """Check if memory usage exceeds threshold."""
        memory = psutil.virtual_memory()
        usage_percent = memory.percent
        
        if usage_percent > self.threshold * 100:
            self.logger.warning(
                f"High memory usage: {usage_percent:.1f}% "
                f"(Available: {memory.available / (1024**2):.1f} MB)"
            )
            return True
        return False
    
    def monitor(self, callback: Callable[[], None] = None):
        """Start memory monitoring."""
        import time
        
        while True:
            if self.check_memory() and callback:
                callback()  # Call memory cleanup callback
            
            time.sleep(self.check_interval)
```

## State Serialization and Persistence

### 1. Efficient State Serialization

Use efficient serialization formats for state persistence:

```python
import msgpack
import json
import pickle
from typing import Any, Dict

class StateSerializer:
    @staticmethod
    def serialize(state: Dict[str, Any], method: str = "msgpack") -> bytes:
        """Serialize state using specified method."""
        if method == "msgpack":
            return msgpack.packb(state, use_bin_type=True)
        elif method == "json":
            return json.dumps(state).encode('utf-8')
        elif method == "pickle":
            return pickle.dumps(state)
        else:
            raise ValueError(f"Unknown serialization method: {method}")
    
    @staticmethod
    def deserialize(data: bytes, method: str = "msgpack") -> Dict[str, Any]:
        """Deserialize state."""
        if method == "msgpack":
            return msgpack.unpackb(data, raw=False)
        elif method == "json":
            return json.loads(data.decode('utf-8'))
        elif method == "pickle":
            return pickle.loads(data)
        else:
            raise ValueError(f"Unknown deserialization method: {method}")
```

### 2. Incremental State Persistence

Implement incremental state saving to reduce memory pressure:

```python
import os
import time
from typing import Dict, Any

class IncrementalStateSaver:
    def __init__(self, state_dir: str, max_increments: int = 10):
        self.state_dir = state_dir
        self.max_increments = max_increments
        self.current_increment = 0
        self.last_save_time = time.time()
        
        # Create state directory if it doesn't exist
        os.makedirs(state_dir, exist_ok=True)
    
    def save_increment(self, state: Dict[str, Any]):
        """Save incremental state snapshot."""
        increment_file = os.path.join(
            self.state_dir, 
            f"state_increment_{self.current_increment}.msgpack"
        )
        
        # Serialize and save state
        serialized = StateSerializer.serialize(state, method="msgpack")
        with open(increment_file, 'wb') as f:
            f.write(serialized)
        
        self.current_increment += 1
        
        # Clean up old increments if needed
        if self.current_increment > self.max_increments:
            oldest_file = os.path.join(
                self.state_dir, 
                f"state_increment_{self.current_increment - self.max_increments - 1}.msgpack"
            )
            if os.path.exists(oldest_file):
                os.remove(oldest_file)
    
    def should_save(self, interval: int = 300) -> bool:
        """Check if it's time to save an increment."""
        return time.time() - self.last_save_time > interval
    
    def checkpoint(self, state: Dict[str, Any]):
        """Save complete state checkpoint."""
        checkpoint_file = os.path.join(self.state_dir, "state_checkpoint.msgpack")
        serialized = StateSerializer.serialize(state, method="msgpack")
        with open(checkpoint_file, 'wb') as f:
            f.write(serialized)
```

## Memory Cleanup Strategies

### 1. Automatic Cleanup Hooks

Implement automatic cleanup in graph nodes:

```python
from typing import TypedDict, Any
import gc

def cleanup_node(state: TypedDict) -> dict[str, Any]:
    """Cleanup node to manage memory."""
    
    # Clear temporary variables
    temp_keys = [k for k in state.keys() if k.startswith('temp_')]
    for key in temp_keys:
        del state[key]
    
    # Force garbage collection
    gc.collect()
    
    # Check memory usage
    memory_monitor.check_memory()
    
    return {}
```

### 2. Memory Usage Tracking

Track memory usage per component:

```python
import sys
import tracemalloc
from typing import Dict

class MemoryTracker:
    def __init__(self):
        self.snapshots = []
        self.tracked_objects = {}
        
    def start_tracking(self):
        """Start memory tracking."""
        tracemalloc.start()
    
    def take_snapshot(self, label: str = ""):
        """Take memory snapshot."""
        snapshot = tracemalloc.take_snapshot()
        self.snapshots.append((label, snapshot))
        return snapshot
    
    def track_object(self, obj: Any, name: str):
        """Track memory usage of specific object."""
        size = sys.getsizeof(obj)
        self.tracked_objects[name] = size
        return size
    
    def get_summary(self) -> Dict[str, Any]:
        """Get memory usage summary."""
        memory = psutil.virtual_memory()
        return {
            'total': memory.total,
            'available': memory.available,
            'used': memory.used,
            'percent': memory.percent,
            'tracked_objects': self.tracked_objects,
            'num_snapshots': len(self.snapshots)
        }
```

## Production Considerations

### 1. Memory Limits and Alerts

Set up memory limits and alerting:

```python
import logging
from typing import Callable

class MemoryManager:
    def __init__(self, 
                 soft_limit_gb: float = 4.0,
                 hard_limit_gb: float = 6.0,
                 alert_callback: Callable[[float], None] = None):
        self.soft_limit_gb = soft_limit_gb
        self.hard_limit_gb = hard_limit_gb
        self.alert_callback = alert_callback
        self.logger = logging.getLogger(__name__)
        
    def check_limits(self) -> bool:
        """Check memory limits and trigger alerts if needed."""
        memory = psutil.virtual_memory()
        used_gb = memory.used / (1024**3)
        
        if used_gb > self.hard_limit_gb:
            self.logger.critical(f"CRITICAL: Memory usage {used_gb:.1f}GB exceeds hard limit")
            if self.alert_callback:
                self.alert_callback(used_gb)
            return False
        elif used_gb > self.soft_limit_gb:
            self.logger.warning(f"WARNING: Memory usage {used_gb:.1f}GB exceeds soft limit")
            if self.alert_callback:
                self.alert_callback(used_gb)
        
        return True
```

### 2. Graceful Degradation

Implement graceful degradation when memory is constrained:

```python
def handle_memory_pressure(state: TypedDict) -> TypedDict:
    """Handle memory pressure by degrading functionality."""
    
    # Check current memory usage
    memory = psutil.virtual_memory()
    used_gb = memory.used / (1024**3)
    
    if used_gb > 5.0:  # High memory pressure
        # Reduce functionality
        if 'extensive_cache' in state:
            del state['extensive_cache']
        
        if 'large_embeddings' in state:
            state['large_embeddings'] = None
        
        # Reduce logging verbosity
        logging.getLogger().setLevel(logging.WARNING)
    
    return state
```

### 3. Monitoring and Observability

Set up comprehensive monitoring:

```python
import prometheus_client as prom
from typing import Dict

class LangGraphMetrics:
    def __init__(self):
        # Memory metrics
        self.memory_usage = prom.Gauge(
            'langgraph_memory_usage_bytes', 
            'Current memory usage in bytes'
        )
        self.memory_limit = prom.Gauge(
            'langgraph_memory_limit_bytes', 
            'Configured memory limit in bytes'
        )
        
        # State metrics
        self.state_size = prom.Gauge(
            'langgraph_state_size_bytes', 
            'Current state size in bytes'
        )
        self.state_item_count = prom.Gauge(
            'langgraph_state_item_count', 
            'Number of items in state'
        )
    
    def update_metrics(self, state: Dict[str, Any]):
        """Update metrics from current state."""
        memory = psutil.virtual_memory()
        self.memory_usage.set(memory.used)
        self.memory_limit.set(memory.total)
        
        # Estimate state size
        state_size = sum(sys.getsizeof(v) for v in state.values())
        self.state_size.set(state_size)
        self.state_item_count.set(len(state))
```

## Best Practices Summary

### Memory Management Checklist

- [ ] Implement state size limits and pruning
- [ ] Use connection pooling for resources
- [ ] Implement incremental state persistence
- [ ] Set up memory monitoring and alerting
- [ ] Use efficient serialization formats
- [ ] Implement automatic cleanup hooks
- [ ] Track memory usage per component
- [ ] Set up graceful degradation for memory pressure
- [ ] Implement comprehensive monitoring and observability
- [ ] Test memory usage under load conditions

### Performance Optimization Tips

1. **Minimize state size**: Store only essential data in state
2. **Use streaming**: Process large data in chunks rather than loading entirely into memory
3. **Cache wisely**: Implement cache size limits and eviction policies
4. **Profile regularly**: Use memory profiling tools to identify leaks
5. **Test under load**: Simulate production memory usage patterns
6. **Monitor continuously**: Set up real-time memory monitoring

This documentation provides a comprehensive foundation for managing memory in long-running LangGraph applications. The strategies outlined here will help ensure your applications remain stable, performant, and resource-efficient over extended periods of operation.