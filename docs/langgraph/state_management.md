# LangGraph State Management Patterns

This guide covers comprehensive state management patterns for building robust LangGraph applications, including state design, persistence, and best practices.

## Core State Management Concepts

### State as Shared Memory

In LangGraph, state serves as the shared memory across all nodes in your graph. It's a centralized store that allows nodes to communicate and maintain context throughout the execution flow.

#### Key Principles:
- **Single Source of Truth**: All nodes read from and write to the same state object
- **TypedDict Structure**: Use Python's TypedDict for type-safe state definitions
- **Raw Data Storage**: Store unprocessed data in state, format prompts within nodes
- **Immutability**: Nodes return state updates rather than modifying state directly

### State Design Patterns

#### 1. TypedDict State Structure

Define your state structure using TypedDict to ensure type safety and clear documentation:

```python
from typing import TypedDict, List, Dict, Any, Optional

class AgentState(TypedDict):
    # Core data fields
    raw_data: str
    classification: Dict[str, Any] | None
    results: List[Dict[str, Any]] | None
    
    # User preferences and history
    liked_embeddings: List[float] | None
    query_history: List[str] | None
    
    # External connections
    postgres_client: object | None
    neo4j_connection: object | None
    ollama_client: object | None
    
    # Execution metadata
    step_count: int
    error_count: int
    execution_time: float
    
    # Intermediate results
    embeddings: List[float] | None
    similarity_scores: List[float] | None
    processed_data: Dict[str, Any] | None
```

#### 2. State Initialization Patterns

```python
def initialize_state(initial_data: str) -> AgentState:
    """Initialize state with default values."""
    return {
        "raw_data": initial_data,
        "classification": None,
        "results": None,
        "liked_embeddings": [],
        "query_history": [],
        "postgres_client": None,
        "neo4j_connection": None,
        "ollama_client": None,
        "step_count": 0,
        "error_count": 0,
        "execution_time": 0.0,
        "embeddings": None,
        "similarity_scores": None,
        "processed_data": None
    }
```

#### 3. State Update Patterns

```python
def update_state_with_results(state: AgentState, new_results: List[Dict[str, Any]]) -> AgentState:
    """Update state with new results while preserving existing data."""
    return {
        **state,
        "results": new_results,
        "step_count": state["step_count"] + 1,
        "query_history": [*state["query_history"], state["raw_data"]]
    }


def update_state_with_error(state: AgentState, error_message: str) -> AgentState:
    """Update state with error information."""
    return {
        **state,
        "error_count": state["error_count"] + 1,
        "last_error": error_message
    }
```

## State Persistence Patterns

### 1. In-Memory State

For short-lived operations, use in-memory state:

```python
from langgraph.graph import StateGraph

state = initialize_state("initial data")
graph = StateGraph(state)
```

### 2. File-Based Persistence

Persist state to disk for recovery and debugging:

```python
import json
import os
from typing import TypedDict

class PersistentState(TypedDict):
    state_data: dict
    timestamp: str
    version: str

PERSISTENCE_FILE = "/tmp/langgraph_state.json"


def save_state_to_file(state: AgentState) -> None:
    """Save state to JSON file."""
    persistent_state: PersistentState = {
        "state_data": state,
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0"
    }
    
    with open(PERSISTENCE_FILE, "w") as f:
        json.dump(persistent_state, f, indent=2)


def load_state_from_file() -> AgentState | None:
    """Load state from JSON file."""
    if not os.path.exists(PERSISTENCE_FILE):
        return None
    
    try:
        with open(PERSISTENCE_FILE, "r") as f:
            persistent_state = json.load(f)
        return persistent_state["state_data"]
    except (json.JSONDecodeError, KeyError):
        return None
```

### 3. Database Persistence

Persist state in databases for long-running applications:

```python
import psycopg2
from typing import TypedDict

class DatabaseState(TypedDict):
    state_id: str
    state_data: dict
    created_at: str
    updated_at: str


def save_state_to_postgresql(state: AgentState, conn) -> str:
    """Save state to PostgreSQL."""
    state_id = str(uuid.uuid4())
    state_data = json.dumps(state)
    
    with conn.cursor() as cursor:
        cursor.execute("
            INSERT INTO langgraph_states (state_id, state_data, created_at, updated_at)
            VALUES (%s, %s, NOW(), NOW())
            RETURNING state_id
        ", (state_id, state_data))
        
        conn.commit()
    
    return state_id


def load_state_from_postgresql(state_id: str, conn) -> AgentState | None:
    """Load state from PostgreSQL."""
    with conn.cursor() as cursor:
        cursor.execute("
            SELECT state_data FROM langgraph_states 
            WHERE state_id = %s
        ", (state_id,))
        
        result = cursor.fetchone()
        if result:
            return json.loads(result[0])
    
    return None
```

## State Management Best Practices

### 1. State Granularity

Choose appropriate state granularity based on your use case:

#### Fine-Grained State
```python
class FineGrainedState(TypedDict):
    # Store individual pieces of data
    user_query: str
    search_results: List[Dict]
    classification_scores: List[float]
    processing_steps: List[Dict]
```

#### Coarse-Grained State
```python
class CoarseGrainedState(TypedDict):
    # Store aggregated data
    workflow_data: Dict[str, Any]
    metadata: Dict[str, Any]
    results: List[Dict]
```

### 2. State Validation

Validate state before and after node execution:

```python
from pydantic import BaseModel, ValidationError

class StateValidator(BaseModel):
    raw_data: str
    classification: dict | None
    results: list | None
    # ... other fields


def validate_state(state: AgentState) -> bool:
    """Validate state using Pydantic."""
    try:
        StateValidator(**state)
        return True
    except ValidationError as e:
        print(f"State validation error: {e}")
        return False
```

### 3. State Compression

For large state objects, implement compression:

```python
import zlib
import base64


def compress_state(state: AgentState) -> str:
    """Compress state for storage."""
    state_json = json.dumps(state)
    compressed = zlib.compress(state_json.encode('utf-8'))
    return base64.b64encode(compressed).decode('utf-8')


def decompress_state(compressed_state: str) -> AgentState:
    """Decompress state from storage."""
    compressed = base64.b64decode(compressed_state.encode('utf-8'))
    state_json = zlib.decompress(compressed).decode('utf-8')
    return json.loads(state_json)
```

## Advanced State Patterns

### 1. State Versioning

Implement state versioning for backward compatibility:

```python
class VersionedState(TypedDict):
    version: str
    data: dict
    migrated: bool


def migrate_state(old_state: dict, current_version: str) -> VersionedState:
    """Migrate state to current version."""
    # Migration logic based on version
    if old_state.get('version') == '0.9.0':
        return {
            "version": current_version,
            "data": migrate_from_v0_9_0(old_state),
            "migrated": True
        }
    
    return {
        "version": current_version,
        "data": old_state,
        "migrated": False
    }
```

### 2. State Partitioning

Partition state for complex applications:

```python
class PartitionedState(TypedDict):
    # Core state
    core: AgentState
    
    # User-specific state
    user: Dict[str, Any]
    
    # System state
    system: Dict[str, Any]
    
    # Temporary state
    temporary: Dict[str, Any]
```

### 3. State Caching

Implement state caching for performance:

```python
from functools import lru_cache

@lru_cache(maxsize=128)
def get_cached_state(state_id: str) -> AgentState:
    """Get state from cache."""
    return load_state_from_postgresql(state_id, get_db_connection())
```

## State Management in Different Contexts

### 1. Single-User Applications

For single-user scenarios, maintain simple state:

```python
class SingleUserState(TypedDict):
    user_id: str
    current_session: str
    preferences: Dict[str, Any]
    history: List[Dict]
```

### 2. Multi-User Applications

For multi-user scenarios, include user isolation:

```python
class MultiUserState(TypedDict):
    user_states: Dict[str, AgentState]
    active_users: List[str]
    session_mapping: Dict[str, str]
```

### 3. Distributed Systems

For distributed systems, implement state synchronization:

```python
class DistributedState(TypedDict):
    local_state: AgentState
    remote_state: Dict[str, AgentState]
    sync_timestamp: str
    conflict_resolution: str
```

## Common State Management Patterns

### 1. State Reset Pattern

```python
def reset_state(state: AgentState, preserve: List[str] = []) -> AgentState:
    """Reset state while preserving specified fields."""
    initial_state = initialize_state("")
    
    return {
        **initial_state,
        **{key: state[key] for key in preserve if key in state}
    }
```

### 2. State Merge Pattern

```python
def merge_states(base_state: AgentState, new_data: dict) -> AgentState:
    """Merge new data into existing state."""
    return {
        **base_state,
        **new_data
    }
```

### 3. State Validation Pattern

```python
def validate_and_update_state(state: AgentState, updates: dict) -> tuple[bool, AgentState]:
    """Validate and apply updates to state."""
    try:
        updated_state = merge_states(state, updates)
        if validate_state(updated_state):
            return True, updated_state
        return False, state
    except Exception as e:
        return False, state
```

## Debugging State Management

### 1. State Inspection

```python
def inspect_state(state: AgentState, depth: int = 2) -> str:
    """Create readable state inspection output."""
    import pprint
    pp = pprint.PrettyPrinter(indent=2, depth=depth)
    return pp.pformat(state)
```

### 2. State Change Tracking

```python
class StateChangeTracker:
    def __init__(self):
        self.history = []
        
    def track_change(self, old_state: AgentState, new_state: AgentState) -> None:
        """Track state changes."""
        change = {
            "timestamp": datetime.now().isoformat(),
            "changes": self._calculate_diff(old_state, new_state)
        }
        self.history.append(change)
    
    def _calculate_diff(self, old: AgentState, new: AgentState) -> dict:
        """Calculate differences between states."""
        diff = {}
        for key in set(old.keys()).union(new.keys()):
            if old.get(key) != new.get(key):
                diff[key] = {
                    "old": old.get(key),
                    "new": new.get(key)
                }
        return diff
```

## Performance Considerations

### 1. State Size Optimization

```python
def optimize_state_size(state: AgentState) -> AgentState:
    """Optimize state size by removing unnecessary data."""
    optimized = {}
    
    for key, value in state.items():
        if value is not None and len(str(value)) > 0:
            if isinstance(value, (list, dict)):
                if len(value) > 0:
                    optimized[key] = value
            else:
                optimized[key] = value
    
    return optimized
```

### 2. State Access Patterns

```python
class StateAccessPatterns:
    @staticmethod
    def get_nested_value(state: AgentState, path: str, default=None):
        """Get nested value from state using dot notation."""
        keys = path.split('.')
        value = state
        
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default
        
        return value
    
    @staticmethod
    def set_nested_value(state: AgentState, path: str, value):
        """Set nested value in state using dot notation."""
        keys = path.split('.')
        target = state
        
        for key in keys[:-1]:
            if key not in target:
                target[key] = {}
            target = target[key]
        
        target[keys[-1]] = value
        return state
```

## Error Handling in State Management

### 1. State Recovery

```python
def recover_state_from_error(state: AgentState, error: Exception) -> AgentState:
    """Recover state after error."""
    return {
        **state,
        "last_error": str(error),
        "error_count": state.get("error_count", 0) + 1,
        "last_valid_state": state.copy()
    }
```

### 2. State Rollback

```python
def rollback_state(state: AgentState, checkpoint: AgentState) -> AgentState:
    """Rollback state to checkpoint."""
    return {
        **checkpoint,
        "rollback_count": state.get("rollback_count", 0) + 1,
        "rollback_from": checkpoint.copy()
    }
```

This comprehensive guide covers all aspects of LangGraph state management, from basic patterns to advanced techniques. Use these patterns to build robust, maintainable, and scalable LangGraph applications.