# LangGraph State Persistence Best Practices

## Overview

This guide covers comprehensive state persistence patterns for LangGraph applications, including checkpointing strategies, database integration, serialization techniques, and production deployment considerations.

---

## Core Persistence Concepts

### 1.1 Checkpointing Fundamentals

Checkpointing is the primary mechanism for state persistence in LangGraph, allowing applications to save and resume execution state.

#### 1.1.1 Basic Checkpointing Pattern

```python
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver
from typing import TypedDict

class PersistentState(TypedDict):
    user_input: str
    conversation_history: list
    current_step: str
    metadata: dict


def create_checkpointed_app() -> StateGraph:
    """Create app with checkpointing"""
    graph = StateGraph(PersistentState)
    
    # Add nodes
    graph.add_node("input", input_node)
    graph.add_node("process", process_node)
    graph.add_node("respond", respond_node)
    
    # Set entry point
    graph.set_entry_point("input")
    
    # Add edges
    graph.add_edge("input", "process")
    graph.add_edge("process", "respond")
    graph.add_edge("respond", END)
    
    return graph

# Create checkpointed app
app = create_checkpointed_app()

# Configure checkpointing
memory_checkpointer = MemorySaver()
compiled_app = app.compile(checkpointer=memory_checkpointer)

# Run with checkpointing
initial_state = {"user_input": "hello", "conversation_history": [], "current_step": "input", "metadata": {}}
result = compiled_app.invoke(initial_state)

# Resume from checkpoint
resume_result = compiled_app.invoke(None)
```

#### 1.1.2 State Serialization for Checkpointing

```python
from typing import TypedDict, Any
import json
from datetime import datetime

class SerializableState(TypedDict):
    data: dict
    version: str
    timestamp: str
    metadata: dict


def serialize_state(state: dict) -> str:
    """Serialize state for checkpointing"""
    serializable: SerializableState = {
        "data": state,
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat(),
        "metadata": {
            "checkpointed_at": datetime.now().isoformat(),
            "source": "application"
        }
    }
    
    return json.dumps(serializable, indent=2)


def deserialize_state(serialized: str) -> dict:
    """Deserialize state from checkpoint"""
    data = json.loads(serialized)
    
    # Validate version
    if data.get("version") != "1.0.0":
        raise ValueError(f"Unsupported state version: {data.get('version')}")
    
    return data["data"]
```

### 1.2 Checkpointer Types

LangGraph supports multiple checkpointer backends for different use cases.

#### 1.2.1 Memory Checkpointer

```python
from langgraph.checkpoint.memory import MemorySaver

# In-memory checkpointing (fast, ephemeral)
memory_checkpointer = MemorySaver()

# Configure app
app = graph.compile(checkpointer=memory_checkpointer)

# List checkpoints
checkpoints = memory_checkpointer.list(config)
for checkpoint in checkpoints:
    print(f"ID: {checkpoint['id']}, Created: {checkpoint['metadata']['created_at']}")

# Get specific checkpoint
checkpoint_id = "checkpoint-123"
checkpoint = memory_checkpointer.get(config, checkpoint_id=checkpoint_id)

# Delete old checkpoints
memory_checkpointer.delete(config, checkpoint_id)
```

#### 1.2.2 SQLite Checkpointer

```python
from langgraph.checkpoint.sqlite import SqliteSaver

# File-based SQLite checkpointing
sqlite_checkpointer = SqliteSaver.from_conn_string("checkpoints.db")

# In-memory SQLite for testing
sqlite_checkpointer = SqliteSaver.from_conn_string(":memory:")

# Configure app
app = graph.compile(checkpointer=sqlite_checkpointer)

# List checkpoints
checkpoints = sqlite_checkpointer.list(config)
for checkpoint in checkpoints:
    print(f"ID: {checkpoint['id']}, Created: {checkpoint['metadata']['created_at']}")

# Cleanup old checkpoints
sqlite_checkpointer.delete_old_checkpoints(config, keep_last=10)
```

#### 1.2.3 PostgreSQL Checkpointer

```python
from langgraph.checkpoint.postgres import PostgresSaver

# PostgreSQL checkpointing
postgres_checkpointer = PostgresSaver.from_conn_string(
    "postgresql://user:password@localhost:5432/langgraph"
)

# With connection pooling
postgres_checkpointer = PostgresSaver.from_conn_string(
    "postgresql://user:password@localhost:5432/langgraph",
    pool_size=10
)

# Configure app
app = graph.compile(checkpointer=postgres_checkpointer)

# List checkpoints with pagination
checkpoints = postgres_checkpointer.list(config, limit=50, offset=0)

# Get checkpoint statistics
stats = postgres_checkpointer.get_stats(config)
print(f"Total checkpoints: {stats['total']}")
```

---

## Advanced Persistence Patterns

### 2.1 Custom Checkpointer Implementation

Create custom checkpointing solutions for specific requirements.

#### 2.1.1 Custom Checkpointer Class

```python
from langgraph.checkpoint.base import BaseCheckpointSaver, Checkpoint
from typing import List, Dict, Any
import boto3
from datetime import datetime

class S3Checkpointer(BaseCheckpointSaver):
    def __init__(self, bucket_name: str, prefix: str = "checkpoints"):
        self.s3 = boto3.client('s3')
        self.bucket_name = bucket_name
        self.prefix = prefix
    
    def put(self, config: Dict, checkpoint: Checkpoint, metadata: Dict, **kwargs) -> Dict:
        """Save checkpoint to S3"""
        checkpoint_id = checkpoint.id
        state_data = checkpoint.state
        
        # Serialize state
        serialized_state = json.dumps(state_data)
        
        # Create S3 key
        s3_key = f"{self.prefix}/{checkpoint_id}.json"
        
        # Upload to S3
        self.s3.put_object(
            Bucket=self.bucket_name,
            Key=s3_key,
            Body=serialized_state,
            Metadata={
                "created_at": metadata.get("created_at", datetime.now().isoformat()),
                "thread_id": config.get("configurable", {}).get("thread_id", "default")
            }
        )
        
        return {"s3_key": s3_key}
    
    def get(self, config: Dict, **kwargs) -> Checkpoint | None:
        """Retrieve checkpoint from S3"""
        checkpoint_id = kwargs.get("checkpoint_id")
        if not checkpoint_id:
            return None
        
        # Create S3 key
        s3_key = f"{self.prefix}/{checkpoint_id}.json"
        
        try:
            # Download from S3
            response = self.s3.get_object(Bucket=self.bucket_name, Key=s3_key)
            serialized_state = response["Body"].read().decode('utf-8')
            state_data = json.loads(serialized_state)
            
            # Create checkpoint
            checkpoint = Checkpoint(
                id=checkpoint_id,
                state=state_data,
                metadata={
                    "created_at": response["Metadata"].get("created_at"),
                    "thread_id": response["Metadata"].get("thread_id")
                }
            )
            
            return checkpoint
            
        except self.s3.exceptions.NoSuchKey:
            return None
    
    def list(self, config: Dict, **kwargs) -> List[Dict]:
        """List checkpoints in S3"""
        prefix = f"{self.prefix}/"
        
        # List objects in S3
        response = self.s3.list_objects_v2(
            Bucket=self.bucket_name,
            Prefix=prefix
        )
        
        checkpoints = []
        if "Contents" in response:
            for item in response["Contents"]:
                key = item["Key"]
                checkpoint_id = key.replace(f"{self.prefix}/", "").replace(".json", "")
                
                # Get object metadata
                head_response = self.s3.head_object(Bucket=self.bucket_name, Key=key)
                metadata = head_response.get("Metadata", {})
                
                checkpoints.append({
                    "id": checkpoint_id,
                    "created_at": metadata.get("created_at"),
                    "thread_id": metadata.get("thread_id"),
                    "size": item["Size"]
                })
        
        return checkpoints
    
    def delete(self, config: Dict, **kwargs) -> None:
        """Delete checkpoint from S3"""
        checkpoint_id = kwargs.get("checkpoint_id")
        if not checkpoint_id:
            return
        
        # Create S3 key
        s3_key = f"{self.prefix}/{checkpoint_id}.json"
        
        # Delete from S3
        self.s3.delete_object(Bucket=self.bucket_name, Key=s3_key)
```

#### 2.1.2 Custom Serialization

```python
import pickle
import zlib
from typing import Any

class CustomSerializer:
    @staticmethod
    def serialize(state: Any) -> bytes:
        """Custom serialization with compression"""
        # Convert to JSON string
        json_str = json.dumps(state)
        
        # Compress
        compressed = zlib.compress(json_str.encode('utf-8'))
        
        return compressed
    
    @staticmethod
    def deserialize(serialized: bytes) -> Any:
        """Custom deserialization"""
        # Decompress
        decompressed = zlib.decompress(serialized)
        
        # Convert from JSON string
        json_str = decompressed.decode('utf-8')
        state = json.loads(json_str)
        
        return state

# Use with custom checkpointer
class CustomSerializedCheckpointer(S3Checkpointer):
    def put(self, config: Dict, checkpoint: Checkpoint, metadata: Dict, **kwargs) -> Dict:
        """Save checkpoint with custom serialization"""
        checkpoint_id = checkpoint.id
        state_data = checkpoint.state
        
        # Serialize with custom serializer
        serialized_state = CustomSerializer.serialize(state_data)
        
        # Upload to S3
        s3_key = f"{self.prefix}/{checkpoint_id}.bin"
        self.s3.put_object(
            Bucket=self.bucket_name,
            Key=s3_key,
            Body=serialized_state,
            Metadata={"created_at": metadata.get("created_at")}
        )
        
        return {"s3_key": s3_key}
    
    def get(self, config: Dict, **kwargs) -> Checkpoint | None:
        """Retrieve checkpoint with custom deserialization"""
        checkpoint_id = kwargs.get("checkpoint_id")
        if not checkpoint_id:
            return None
        
        s3_key = f"{self.prefix}/{checkpoint_id}.bin"
        
        try:
            response = self.s3.get_object(Bucket=self.bucket_name, Key=s3_key)
            serialized_state = response["Body"].read()
            state_data = CustomSerializer.deserialize(serialized_state)
            
            checkpoint = Checkpoint(
                id=checkpoint_id,
                state=state_data,
                metadata={"created_at": response["Metadata"].get("created_at")}
            )
            
            return checkpoint
            
        except self.s3.exceptions.NoSuchKey:
            return None
```

### 2.2 State Versioning and Migration

Handle state schema changes and migrations.

#### 2.2.1 State Versioning Pattern

```python
from typing import TypedDict, Literal

class VersionedState(TypedDict):
    version: str
    data: dict
    migrated: bool
    migration_history: list


def migrate_state(state: dict, target_version: str = "2.0.0") -> VersionedState:
    """Migrate state to target version"""
    current_version = state.get("version", "1.0.0")
    
    if current_version == target_version:
        return {
            "version": current_version,
            "data": state.get("data", state),
            "migrated": False,
            "migration_history": []
        }
    
    migration_history = []
    current_data = state.get("data", state)
    
    # Migration path: 1.0.0 -> 1.1.0 -> 2.0.0
    if current_version == "1.0.0":
        current_data, changes = migrate_v1_to_v1_1(current_data)
        migration_history.append({
            "from": "1.0.0",
            "to": "1.1.0",
            "changes": changes,
            "timestamp": datetime.now().isoformat()
        })
        current_version = "1.1.0"
    
    if current_version == "1.1.0":
        current_data, changes = migrate_v1_1_to_v2_0(current_data)
        migration_history.append({
            "from": "1.1.0",
            "to": "2.0.0",
            "changes": changes,
            "timestamp": datetime.now().isoformat()
        })
        current_version = "2.0.0"
    
    return {
        "version": current_version,
        "data": current_data,
        "migrated": True,
        "migration_history": migration_history
    }

# Migration functions
def migrate_v1_to_v1_1(data: dict) -> tuple[dict, list]:
    """Migrate from v1.0.0 to v1.1.0"""
    changes = []
    
    # Example: Add new field with default value
    if "new_field" not in data:
        data["new_field"] = "default_value"
        changes.append("Added new_field with default value")
    
    # Example: Rename field
    if "old_field_name" in data:
        data["new_field_name"] = data.pop("old_field_name")
        changes.append("Renamed old_field_name to new_field_name")
    
    return data, changes


def migrate_v1_1_to_v2_0(data: dict) -> tuple[dict, list]:
    """Migrate from v1.1.0 to v2.0.0"""
    changes = []
    
    # Example: Change data structure
    if "nested_data" in data:
        # Flatten nested structure
        for key, value in data["nested_data"].items():
            data[f"nested_{key}"] = value
        del data["nested_data"]
        changes.append("Flattened nested_data structure")
    
    return data, changes
```

#### 2.2.2 Backward Compatibility

```python
def load_state_with_migration(serialized_state: str) -> dict:
    """Load state with automatic migration"""
    state = json.loads(serialized_state)
    
    # Check if state needs migration
    if "version" not in state:
        # Old format, migrate to v1.0.0
        state = {
            "version": "1.0.0",
            "data": state,
            "migrated": False,
            "migration_history": []
        }
    
    # Migrate to latest version if needed
    if state["version"] != "2.0.0":
        state = migrate_state(state, "2.0.0")
    
    return state["data"]
```

---

## Database Integration Patterns

### 3.1 PostgreSQL Integration

Persist state in PostgreSQL for production applications.

#### 3.1.1 PostgreSQL State Storage

```python
import psycopg2
from typing import TypedDict, Optional
from datetime import datetime

class PostgresState(TypedDict):
    state_id: str
    state_data: dict
    created_at: str
    updated_at: str
    version: str
    metadata: dict


def create_state_table(conn) -> None:
    """Create state table in PostgreSQL"""
    with conn.cursor() as cursor:
        cursor.execute(""")
        CREATE TABLE IF NOT EXISTS langgraph_states (
            state_id UUID PRIMARY KEY,
            state_data JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            version VARCHAR(20) NOT NULL,
            metadata JSONB
        )
        
        -- Indexes for performance
        CREATE INDEX IF NOT EXISTS idx_langgraph_states_created_at ON langgraph_states(created_at);
        CREATE INDEX IF NOT EXISTS idx_langgraph_states_updated_at ON langgraph_states(updated_at);
        CREATE INDEX IF NOT EXISTS idx_langgraph_states_version ON langgraph_states(version);
        CREATE INDEX IF NOT EXISTS idx_langgraph_states_metadata ON langgraph_states USING GIN(metadata);
        """)
        conn.commit()


def save_state_to_postgres(state: dict, conn) -> str:
    """Save state to PostgreSQL"""
    state_id = str(uuid.uuid4())
    state_data = json.dumps(state)
    
    with conn.cursor() as cursor:
        cursor.execute(""")
        INSERT INTO langgraph_states (state_id, state_data, created_at, updated_at, version, metadata)
        VALUES (%s, %s, NOW(), NOW(), %s, %s)
        RETURNING state_id
        """, (state_id, state_data, "1.0.0", json.dumps({})))
        
        conn.commit()
    
    return state_id


def load_state_from_postgres(state_id: str, conn) -> Optional[dict]:
    """Load state from PostgreSQL"""
    with conn.cursor() as cursor:
        cursor.execute(""")
        SELECT state_data FROM langgraph_states 
        WHERE state_id = %s
        """, (state_id,))
        
        result = cursor.fetchone()
        if result:
            return json.loads(result[0])
    
    return None
```

#### 3.1.2 PostgreSQL Checkpointer Integration

```python
from langgraph.checkpoint.postgres import PostgresSaver
from typing import Dict, Any

class CustomPostgresCheckpointer(PostgresSaver):
    def __init__(self, conn_string: str, table_name: str = "langgraph_states"):
        super().__init__(conn_string)
        self.table_name = table_name
    
    def put(self, config: Dict, checkpoint: Checkpoint, metadata: Dict, **kwargs) -> Dict:
        """Save checkpoint to PostgreSQL"""
        state_id = checkpoint.id
        state_data = checkpoint.state
        
        # Serialize state
        serialized_state = json.dumps(state_data)
        
        with self.get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(f"""
                INSERT INTO {self.table_name} 
                (state_id, state_data, created_at, updated_at, version, metadata)
                VALUES (%s, %s, NOW(), NOW(), %s, %s)
                ON CONFLICT (state_id) 
                DO UPDATE SET 
                    state_data = EXCLUDED.state_data,
                    updated_at = EXCLUDED.updated_at,
                    version = EXCLUDED.version,
                    metadata = EXCLUDED.metadata
                """, (
                    state_id,
                    serialized_state,
                    "1.0.0",
                    json.dumps(metadata)
                ))
                
                conn.commit()
        
        return {"state_id": state_id}
    
    def get(self, config: Dict, **kwargs) -> Checkpoint | None:
        """Retrieve checkpoint from PostgreSQL"""
        state_id = kwargs.get("checkpoint_id")
        if not state_id:
            return None
        
        with self.get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(f"""
                SELECT state_data, created_at, updated_at, version, metadata 
                FROM {self.table_name}
                WHERE state_id = %s
                """, (state_id,))
                
                result = cursor.fetchone()
                if result:
                    state_data, created_at, updated_at, version, metadata = result
                    
                    checkpoint = Checkpoint(
                        id=state_id,
                        state=json.loads(state_data),
                        metadata={
                            "created_at": created_at.isoformat(),
                            "updated_at": updated_at.isoformat(),
                            "version": version,
                            "metadata": json.loads(metadata) if metadata else {}
                        }
                    )
                    
                    return checkpoint
        
        return None
```

### 3.2 NoSQL Integration

Persist state in NoSQL databases like MongoDB.

#### 3.2.1 MongoDB State Storage

```python
from pymongo import MongoClient
from typing import TypedDict, Optional
from datetime import datetime
import bson

class MongoState(TypedDict):
    _id: bson.ObjectId
    state_data: dict
    created_at: datetime
    updated_at: datetime
    version: str
    metadata: dict


def create_mongo_client(uri: str, db_name: str, collection_name: str):
    """Create MongoDB client and collection"""
    client = MongoClient(uri)
    db = client[db_name]
    collection = db[collection_name]
    
    # Create indexes
    collection.create_index("created_at")
    collection.create_index("updated_at")
    collection.create_index("version")
    collection.create_index("metadata")
    
    return collection


def save_state_to_mongo(state: dict, collection) -> str:
    """Save state to MongoDB"""
    state_id = bson.ObjectId()
    
    mongo_state = {
        "_id": state_id,
        "state_data": state,
        "created_at": datetime.now(),
        "updated_at": datetime.now(),
        "version": "1.0.0",
        "metadata": {}
    }
    
    collection.insert_one(mongo_state)
    
    return str(state_id)


def load_state_from_mongo(state_id: str, collection) -> Optional[dict]:
    """Load state from MongoDB"""
    mongo_id = bson.ObjectId(state_id)
    
    result = collection.find_one({"_id": mongo_id})
    if result:
        return result["state_data"]
    
    return None
```

---

## Production Deployment Patterns

### 4.1 State Cleanup and Retention

Manage state storage and cleanup in production.

#### 4.1.1 Automatic Cleanup

```python
from datetime import datetime, timedelta
from typing import Dict, Any

class StateCleanupManager:
    def __init__(self, checkpointer, retention_days: int = 30, max_checkpoints: int = 1000):
        self.checkpointer = checkpointer
        self.retention_days = retention_days
        self.max_checkpoints = max_checkpoints
    
    def cleanup_old_checkpoints(self, config: Dict) -> int:
        """Cleanup old checkpoints based on retention policy"""
        # Get all checkpoints
        checkpoints = self.checkpointer.list(config)
        
        # Calculate cutoff date
        cutoff_date = datetime.now() - timedelta(days=self.retention_days)
        
        # Find checkpoints to delete
        to_delete = []
        for checkpoint in checkpoints:
            created_at = datetime.fromisoformat(checkpoint["created_at"])
            
            # Delete if older than retention period
            if created_at < cutoff_date:
                to_delete.append(checkpoint["id"])
            
            # Also delete if we have too many checkpoints
            if len(to_delete) > self.max_checkpoints:
                break
        
        # Delete old checkpoints
        deleted_count = 0
        for checkpoint_id in to_delete:
            try:
                self.checkpointer.delete(config, checkpoint_id=checkpoint_id)
                deleted_count += 1
            except Exception as e:
                print(f"Error deleting checkpoint {checkpoint_id}: {e}")
        
        return deleted_count
    
    def cleanup_inactive_sessions(self, config: Dict, inactivity_days: int = 7) -> int:
        """Cleanup inactive sessions"""
        # Get all checkpoints
        checkpoints = self.checkpointer.list(config)
        
        # Calculate inactivity cutoff
        inactivity_cutoff = datetime.now() - timedelta(days=inactivity_days)
        
        # Find inactive sessions
        to_delete = []
        for checkpoint in checkpoints:
            updated_at = datetime.fromisoformat(checkpoint.get("updated_at", checkpoint["created_at"]))
            
            # Delete if inactive for too long
            if updated_at < inactivity_cutoff:
                to_delete.append(checkpoint["id"])
        
        # Delete inactive sessions
        deleted_count = 0
        for checkpoint_id in to_delete:
            try:
                self.checkpointer.delete(config, checkpoint_id=checkpoint_id)
                deleted_count += 1
            except Exception as e:
                print(f"Error deleting checkpoint {checkpoint_id}: {e}")
        
        return deleted_count
```

#### 4.1.2 State Archival

```python
class StateArchivalManager:
    def __init__(self, active_checkpointer, archive_checkpointer, archive_after_days: int = 30):
        self.active_checkpointer = active_checkpointer
        self.archive_checkpointer = archive_checkpointer
        self.archive_after_days = archive_after_days
    
    def archive_old_states(self, config: Dict) -> int:
        """Archive old states to separate storage"""
        # Get all checkpoints
        checkpoints = self.active_checkpointer.list(config)
        
        # Calculate archive cutoff
        archive_cutoff = datetime.now() - timedelta(days=self.archive_after_days)
        
        # Archive old checkpoints
        archived_count = 0
        for checkpoint in checkpoints:
            created_at = datetime.fromisoformat(checkpoint["created_at"])
            
            if created_at < archive_cutoff:
                try:
                    # Get the checkpoint
                    full_checkpoint = self.active_checkpointer.get(config, checkpoint_id=checkpoint["id"])
                    if full_checkpoint:
                        # Save to archive
                        self.archive_checkpointer.put(config, full_checkpoint, checkpoint)
                        
                        # Delete from active
                        self.active_checkpointer.delete(config, checkpoint_id=checkpoint["id"])
                        archived_count += 1
                except Exception as e:
                    print(f"Error archiving checkpoint {checkpoint['id']}: {e}")
        
        return archived_count
    
    def restore_archived_state(self, config: Dict, checkpoint_id: str) -> Checkpoint | None:
        """Restore archived state"""
        # Try to restore from archive first
        archived_checkpoint = self.archive_checkpointer.get(config, checkpoint_id=checkpoint_id)
        if archived_checkpoint:
            return archived_checkpoint
        
        # Fall back to active checkpoint
        return self.active_checkpointer.get(config, checkpoint_id=checkpoint_id)
```

### 4.2 Performance Optimization

Optimize state persistence for production workloads.

#### 4.2.1 State Compression

```python
import zlib
import base64
from typing import Any

class StateCompressor:
    @staticmethod
    def compress_state(state: Any) -> str:
        """Compress state for storage"""
        # Serialize to JSON
        json_str = json.dumps(state)
        
        # Compress
        compressed = zlib.compress(json_str.encode('utf-8'))
        
        # Encode for safe storage
        encoded = base64.b64encode(compressed).decode('utf-8')
        
        return encoded
    
    @staticmethod
    def decompress_state(encoded: str) -> Any:
        """Decompress state from storage"""
        # Decode
        compressed = base64.b64decode(encoded.encode('utf-8'))
        
        # Decompress
        decompressed = zlib.decompress(compressed)
        
        # Deserialize from JSON
        json_str = decompressed.decode('utf-8')
        state = json.loads(json_str)
        
        return state

# Use with custom checkpointer
class CompressedCheckpointer(BaseCheckpointSaver):
    def __init__(self, underlying_checkpointer):
        self.underlying_checkpointer = underlying_checkpointer
    
    def put(self, config: Dict, checkpoint: Checkpoint, metadata: Dict, **kwargs) -> Dict:
        """Save compressed checkpoint"""
        # Compress state
        compressed_state = StateCompressor.compress_state(checkpoint.state)
        
        # Create new checkpoint with compressed state
        compressed_checkpoint = Checkpoint(
            id=checkpoint.id,
            state=compressed_state,
            metadata=checkpoint.metadata
        )
        
        return self.underlying_checkpointer.put(config, compressed_checkpoint, metadata, **kwargs)
    
    def get(self, config: Dict, **kwargs) -> Checkpoint | None:
        """Retrieve and decompress checkpoint"""
        checkpoint = self.underlying_checkpointer.get(config, **kwargs)
        if checkpoint:
            # Decompress state
            decompressed_state = StateCompressor.decompress_state(checkpoint.state)
            
            # Create new checkpoint with decompressed state
            return Checkpoint(
                id=checkpoint.id,
                state=decompressed_state,
                metadata=checkpoint.metadata
            )
        
        return None
```

#### 4.2.2 Batch Persistence

```python
class BatchStateSaver:
    def __init__(self, checkpointer, batch_size: int = 100, flush_interval: int = 60):
        self.checkpointer = checkpointer
        self.batch_size = batch_size
        self.flush_interval = flush_interval
        self.batch = []
        self.last_flush = time.time()
    
    def save_state(self, state: dict, metadata: dict = None) -> None:
        """Save state to batch"""
        self.batch.append({
            "state": state,
            "metadata": metadata or {}
        })
        
        # Flush if batch is full or interval has passed
        if len(self.batch) >= self.batch_size or (time.time() - self.last_flush) > self.flush_interval:
            self.flush_batch()
    
    def flush_batch(self) -> None:
        """Flush batch to checkpoint"""
        if not self.batch:
            return
        
        try:
            # Save all states in batch
            for batch_item in self.batch:
                state = batch_item["state"]
                metadata = batch_item["metadata"]
                
                # Generate checkpoint
                checkpoint = Checkpoint(
                    id=str(uuid.uuid4()),
                    state=state,
                    metadata=metadata
                )
                
                # Save checkpoint
                self.checkpointer.put({}, checkpoint, metadata)
            
            # Clear batch
            self.batch = []
            self.last_flush = time.time()
            
        except Exception as e:
            print(f"Error flushing batch: {e}")
            # Optionally implement retry logic
```

---

## Security and Compliance

### 5.1 Data Sanitization

```python
def sanitize_state_for_storage(state: dict) -> dict:
    """Sanitize state before persisting"""
    sanitized = {}
    
    for key, value in state.items():
        # Remove sensitive fields
        if key in ["password", "secret", "token", "api_key", "private_key"]:
            continue
        
        # Remove large binary data
        if isinstance(value, bytes) and len(value) > 1024:
            continue
        
        # Remove PII if required
        if key in ["ssn", "credit_card", "dob"]:
            continue
        
        sanitized[key] = value
    
    return sanitized

# Use in custom checkpointer
def put(self, config: Dict, checkpoint: Checkpoint, metadata: Dict, **kwargs) -> Dict:
    """Save sanitized checkpoint"""
    sanitized_state = sanitize_state_for_storage(checkpoint.state)
    
    sanitized_checkpoint = Checkpoint(
        id=checkpoint.id,
        state=sanitized_state,
        metadata=checkpoint.metadata
    )
    
    return super().put(config, sanitized_checkpoint, metadata, **kwargs)
```

### 5.2 Encryption

```python
from cryptography.fernet import Fernet
import base64

class EncryptedCheckpointer(BaseCheckpointSaver):
    def __init__(self, underlying_checkpointer, encryption_key: str):
        self.underlying_checkpointer = underlying_checkpointer
        self.encryption_key = base64.urlsafe_b64encode(encryption_key.encode('utf-8'))
        self.cipher = Fernet(self.encryption_key)
    
    def put(self, config: Dict, checkpoint: Checkpoint, metadata: Dict, **kwargs) -> Dict:
        """Save encrypted checkpoint"""
        # Encrypt state
        state_str = json.dumps(checkpoint.state)
        encrypted_state = self.cipher.encrypt(state_str.encode('utf-8'))
        
        encrypted_checkpoint = Checkpoint(
            id=checkpoint.id,
            state=encrypted_state,
            metadata=checkpoint.metadata
        )
        
        return self.underlying_checkpointer.put(config, encrypted_checkpoint, metadata, **kwargs)
    
    def get(self, config: Dict, **kwargs) -> Checkpoint | None:
        """Retrieve and decrypt checkpoint"""
        checkpoint = self.underlying_checkpointer.get(config, **kwargs)
        if checkpoint:
            # Decrypt state
            decrypted_state = self.cipher.decrypt(checkpoint.state).decode('utf-8')
            state = json.loads(decrypted_state)
            
            return Checkpoint(
                id=checkpoint.id,
                state=state,
                metadata=checkpoint.metadata
            )
        
        return None
```

---

## Monitoring and Observability

### 6.1 State Metrics

```python
class StateMetrics:
    def __init__(self, checkpointer):
        self.checkpointer = checkpointer
        self.metrics = {
            "total_checkpoints": 0,
            "total_size": 0,
            "checkpoint_counts": {},
            "error_counts": {},
            "average_size": 0.0,
            "max_size": 0,
            "min_size": float('inf')
        }
    
    def collect_metrics(self, config: Dict) -> Dict:
        """Collect state persistence metrics"""
        checkpoints = self.checkpointer.list(config)
        
        self.metrics["total_checkpoints"] = len(checkpoints)
        self.metrics["total_size"] = sum(c["size"] for c in checkpoints if "size" in c)
        
        # Calculate averages and extremes
        if checkpoints:
            sizes = [c["size"] for c in checkpoints if "size" in c]
            self.metrics["average_size"] = sum(sizes) / len(sizes)
            self.metrics["max_size"] = max(sizes)
            self.metrics["min_size"] = min(sizes)
        else:
            self.metrics["average_size"] = 0.0
            self.metrics["max_size"] = 0
            self.metrics["min_size"] = 0
        
        # Count by version
        version_counts = {}
        for checkpoint in checkpoints:
            version = checkpoint.get("version", "unknown")
            version_counts[version] = version_counts.get(version, 0) + 1
        
        self.metrics["checkpoint_counts"] = version_counts
        
        return self.metrics
    
    def log_metrics(self, config: Dict) -> None:
        """Log state metrics"""
        metrics = self.collect_metrics(config)
        
        print("State Persistence Metrics:")
        print(f"  Total Checkpoints: {metrics['total_checkpoints']}")
        print(f"  Total Size: {metrics['total_size']} bytes")
        print(f"  Average Size: {metrics['average_size']:.2f} bytes")
        print(f"  Max Size: {metrics['max_size']} bytes")
        print(f"  Min Size: {metrics['min_size']} bytes")
        print(f"  Version Distribution: {metrics['checkpoint_counts']}")
```

### 6.2 Health Checks

```python
class StateHealthChecker:
    def __init__(self, checkpointer):
        self.checkpointer = checkpointer
    
    def check_health(self, config: Dict) -> Dict:
        """Perform health check on state persistence"""
        health = {
            "status": "healthy",
            "checks": [],
            "errors": []
        }
        
        # Check 1: Basic connectivity
        try:
            checkpoints = self.checkpointer.list(config)
            health["checks"].append({
                "name": "connectivity",
                "status": "passed",
                "details": f"Found {len(checkpoints)} checkpoints"
            })
        except Exception as e:
            health["status"] = "unhealthy"
            health["checks"].append({
                "name": "connectivity",
                "status": "failed",
                "error": str(e)
            })
            health["errors"].append(str(e))
        
        # Check 2: Read/Write operation
        try:
            test_state = {"health_check": "passed", "timestamp": datetime.now().isoformat()}
            
            # Save test state
            test_checkpoint = Checkpoint(
                id="health-check-" + str(uuid.uuid4()),
                state=test_state,
                metadata={"health_check": True}
            )
            self.checkpointer.put(config, test_checkpoint, {"health_check": True})
            
            # Read test state
            retrieved = self.checkpointer.get(config, checkpoint_id=test_checkpoint.id)
            if retrieved and retrieved.state == test_state:
                health["checks"].append({
                    "name": "read_write",
                    "status": "passed",
                    "details": "Read and write operations successful"
                })
            else:
                health["status"] = "unhealthy"
                health["checks"].append({
                    "name": "read_write",
                    "status": "failed",
                    "details": "Read/write mismatch"
                })
                health["errors"].append("Read/write mismatch")
            
            # Clean up test checkpoint
            self.checkpointer.delete(config, checkpoint_id=test_checkpoint.id)
            
        except Exception as e:
            health["status"] = "unhealthy"
            health["checks"].append({
                "name": "read_write",
                "status": "failed",
                "error": str(e)
            })
            health["errors"].append(str(e))
        
        return health
    
    def log_health(self, config: Dict) -> None:
        """Log health check results"""
        health = self.check_health(config)
        
        print(f"State Persistence Health: {health['status'].upper()}")
        for check in health["checks"]:
            status = "✓" if check["status"] == "passed" else "✗"
            print(f"  {status} {check['name']}: {check.get('details', check.get('error', 'Unknown'))}")
        
        if health["errors"]:
            print("Errors:")
            for error in health["errors"]:
                print(f"  - {error}")
```

---

## Summary

This comprehensive guide covers:

| Topic | Key Points |
|-------|------------|
| **Core Concepts** | Checkpointing fundamentals, serialization, checkpointer types |
| **Advanced Patterns** | Custom checkpointers, state versioning, migration |
| **Database Integration** | PostgreSQL, MongoDB, NoSQL integration |
| **Production Deployment** | Cleanup, archival, performance optimization |
| **Security** | Data sanitization, encryption, compliance |
| **Monitoring** | Metrics, health checks, observability |

---

*Document Version: 1.0*
*Last Updated: January 2026*

---

## Next Steps

After implementing state persistence, explore:
- [Error Handling and Recovery Patterns](../error_handling.md)
- [Advanced Tool Usage](../tools.md)
- [Performance Optimization](../performance.md)
- [Security Considerations](../security.md)