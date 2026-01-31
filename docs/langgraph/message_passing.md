# LangGraph Message Passing Between Nodes

## Overview

This guide covers comprehensive message passing patterns between nodes in LangGraph, including state-based communication, event-driven messaging, and best practices for building robust agent architectures.

---

## Core Message Passing Concepts

### 1.1 State-Based Communication

In LangGraph, message passing is primarily achieved through state updates. Each node receives the current state and returns partial updates that are merged into the shared state.

#### 1.1.1 Basic State Update Pattern

```python
from typing import TypedDict

class MessageState(TypedDict):
    input_message: str
    processed_message: str | None
    response_message: str | None
    metadata: dict | None


def input_node(state: MessageState) -> MessageState:
    """Node that receives and processes input message"""
    # Process the input message
    processed = process_input(state["input_message"])
    
    return {
        "processed_message": processed,
        "metadata": {"source": "input_node"}
    }


def response_node(state: MessageState) -> MessageState:
    """Node that generates response based on processed message"""
    if state.get("processed_message"):
        response = generate_response(state["processed_message"])
        return {
            "response_message": response,
            "metadata": {"source": "response_node"}
        }
    return {"response_message": "No message to respond to"}
```

#### 1.1.2 Message Transformation Pattern

```python
class TransformState(TypedDict):
    raw_message: str
    cleaned_message: str | None
    tokenized_message: list | None
    processed_message: str | None


def clean_message_node(state: TransformState) -> TransformState:
    """Clean and normalize message"""
    cleaned = clean_text(state["raw_message"])
    return {"cleaned_message": cleaned}


def tokenize_message_node(state: TransformState) -> TransformState:
    """Tokenize the cleaned message"""
    if state.get("cleaned_message"):
        tokens = tokenize(state["cleaned_message"])
        return {"tokenized_message": tokens}
    return {}


def process_message_node(state: TransformState) -> TransformState:
    """Process tokenized message"""
    if state.get("tokenized_message"):
        processed = analyze_tokens(state["tokenized_message"])
        return {"processed_message": processed}
    return {}
```

### 1.2 Event-Driven Messaging

While LangGraph primarily uses state-based messaging, you can implement event-driven patterns using state flags and conditional edges.

#### 1.2.1 Event Flag Pattern

```python
class EventState(TypedDict):
    event_type: str | None
    event_data: dict | None
    event_handled: bool
    result: str | None


def event_generator_node(state: EventState) -> EventState:
    """Generate events based on state"""
    if should_generate_event(state):
        return {
            "event_type": "new_data_available",
            "event_data": collect_event_data(state),
            "event_handled": False
        }
    return {"event_handled": True}


def event_handler_node(state: EventState) -> EventState:
    """Handle specific events"""
    if state.get("event_type") == "new_data_available" and not state.get("event_handled"):
        result = handle_event(state["event_data"])
        return {
            "result": result,
            "event_handled": True
        }
    return {"event_handled": True}
```

#### 1.2.2 Event Queue Pattern

```python
class QueueState(TypedDict):
    message_queue: list
    current_message: dict | None
    processed_messages: list
    error_messages: list


def queue_manager_node(state: QueueState) -> QueueState:
    """Manage message queue"""
    if not state.get("current_message") and state["message_queue"]:
        # Get next message from queue
        next_message = state["message_queue"].pop(0)
        return {"current_message": next_message}
    return {}


def message_processor_node(state: QueueState) -> QueueState:
    """Process current message"""
    if state.get("current_message"):
        try:
            result = process_message(state["current_message"])
            return {
                "processed_messages": [*state.get("processed_messages", []), result],
                "current_message": None
            }
        except Exception as e:
            return {
                "error_messages": [*state.get("error_messages", []), str(e)],
                "current_message": None
            }
    return {}
```

---

## Advanced Message Passing Patterns

### 2.1 Message Broadcasting

Broadcast messages to multiple nodes simultaneously.

#### 2.1.1 Parallel Message Processing

```python
class BroadcastState(TypedDict):
    message: str
    processing_results: dict | None
    errors: dict | None


def broadcast_message(state: BroadcastState) -> BroadcastState:
    """Broadcast message to multiple processors"""
    message = state["message"]
    
    # Process with multiple handlers
    results = {}
    errors = {}
    
    # Handler 1
    try:
        result1 = handler_1(message)
        results["handler_1"] = result1
    except Exception as e:
        errors["handler_1"] = str(e)
    
    # Handler 2
    try:
        result2 = handler_2(message)
        results["handler_2"] = result2
    except Exception as e:
        errors["handler_2"] = str(e)
    
    # Handler 3
    try:
        result3 = handler_3(message)
        results["handler_3"] = result3
    except Exception as e:
        errors["handler_3"] = str(e)
    
    return {
        "processing_results": results,
        "errors": errors
    }
```

#### 2.1.2 Fan-Out/Fan-In Pattern

```python
class FanState(TypedDict):
    input_data: list
    partial_results: list | None
    combined_result: any | None
    errors: list | None


def fan_out_node(state: FanState) -> FanState:
    """Fan out data to multiple processors"""
    input_data = state["input_data"]
    
    # Process each item in parallel
    partial_results = []
    errors = []
    
    for item in input_data:
        try:
            result = process_item(item)
            partial_results.append(result)
        except Exception as e:
            errors.append(str(e))
    
    return {
        "partial_results": partial_results,
        "errors": errors
    }


def fan_in_node(state: FanState) -> FanState:
    """Combine partial results"""
    if state.get("partial_results"):
        combined = combine_results(state["partial_results"])
        return {"combined_result": combined}
    return {}
```

### 2.2 Message Routing

Route messages based on content or metadata.

#### 2.2.1 Content-Based Routing

```python
class RoutingState(TypedDict):
    message: str
    message_type: str | None
    routing_result: str | None
    error: str | None


def categorize_message(state: RoutingState) -> RoutingState:
    """Categorize message for routing"""
    message = state["message"]
    
    if "urgent" in message.lower():
        return {"message_type": "urgent"}
    elif "question" in message.lower():
        return {"message_type": "question"}
    elif "command" in message.lower():
        return {"message_type": "command"}
    return {"message_type": "general"}


def route_message(state: RoutingState) -> RoutingState:
    """Route message to appropriate handler"""
    message_type = state.get("message_type")
    
    if message_type == "urgent":
        return {"routing_result": "urgent_handler"}
    elif message_type == "question":
        return {"routing_result": "question_handler"}
    elif message_type == "command":
        return {"routing_result": "command_handler"}
    else:
        return {"routing_result": "general_handler"}
```

#### 2.2.2 Priority-Based Routing

```python
class PriorityState(TypedDict):
    message: str
    priority: int | None
    handling_order: list | None
    processed: bool


def assign_priority(state: PriorityState) -> PriorityState:
    """Assign priority to messages"""
    message = state["message"]
    
    if "high" in message.lower():
        return {"priority": 3}
    elif "medium" in message.lower():
        return {"priority": 2}
    elif "low" in message.lower():
        return {"priority": 1}
    return {"priority": 0}


def sort_by_priority(state: PriorityState) -> PriorityState:
    """Sort messages by priority"""
    if state.get("priority") is not None:
        # In a real implementation, you'd have a queue of messages
        # This would sort them by priority
        sorted_order = sort_messages_by_priority()
        return {"handling_order": sorted_order}
    return {}
```

### 2.3 Message Transformation and Enrichment

Transform and enrich messages as they flow through the system.

#### 2.3.1 Message Enrichment Pattern

```python
class EnrichmentState(TypedDict):
    base_message: str
    enriched_message: str | None
    metadata: dict | None
    enrichment_errors: list | None


def enrich_with_context(state: EnrichmentState) -> EnrichmentState:
    """Enrich message with contextual information"""
    base_message = state["base_message"]
    
    try:
        context = fetch_context(base_message)
        enriched = f"{base_message} (Context: {context})")
        return {
            "enriched_message": enriched,
            "metadata": {"context_added": True}
        }
    except Exception as e:
        return {
            "enrichment_errors": [*state.get("enrichment_errors", []), str(e)]
        }


def enrich_with_metadata(state: EnrichmentState) -> EnrichmentState:
    """Add metadata to message"""
    if state.get("enriched_message"):
        metadata = collect_metadata(state["enriched_message"])
        return {"metadata": metadata}
    return {}
```

#### 2.3.2 Message Translation Pattern

```python
class TranslationState(TypedDict):
    source_message: str
    target_language: str
    translated_message: str | None
    translation_errors: list | None


def detect_language(state: TranslationState) -> TranslationState:
    """Detect source language"""
    source_message = state["source_message"]
    
    try:
        detected_language = detect_language(source_message)
        return {"source_language": detected_language}
    except Exception as e:
        return {"translation_errors": [*state.get("translation_errors", []), str(e)]}


def translate_message(state: TranslationState) -> TranslationState:
    """Translate message to target language"""
    if state.get("source_message") and state.get("target_language"):
        try:
            translated = translate(
                state["source_message"],
                state["target_language"]
            )
            return {"translated_message": translated}
        except Exception as e:
            return {"translation_errors": [*state.get("translation_errors", []), str(e)]}
    return {}
```

---

## Message Passing Best Practices

### 3.1 State Management for Message Passing

#### 3.1.1 Message State Design

Design state schemas specifically for message passing:

```python
class MessageFlowState(TypedDict):
    # Message content
    message_content: str
    message_metadata: dict
    
    # Processing state
    is_processed: bool
    processing_stage: str | None
    processing_errors: list | None
    
    # Routing information
    message_type: str | None
    priority: int | None
    target_handler: str | None
    
    # Timing and tracking
    timestamp: str
    processing_time: float | None
    retries: int
    
    # Historical data
    processing_history: list | None
    transformation_log: list | None
```

#### 3.1.2 Message Validation

Validate messages before processing:

```python
def validate_message(state: MessageFlowState) -> tuple[bool, MessageFlowState]:
    """Validate message before processing"""
    errors = []
    
    # Check required fields
    if not state.get("message_content"):
        errors.append("Message content is required")
    
    # Check message length
    if state.get("message_content") and len(state["message_content"]) > 10000:
        errors.append("Message exceeds maximum length")
    
    # Check message format
    if not isinstance(state.get("message_content"), str):
        errors.append("Message must be a string")
    
    if errors:
        return False, {"processing_errors": errors}
    
    return True, {"is_valid": True}
```

### 3.2 Error Handling in Message Passing

#### 3.2.1 Message Retry Pattern

```python
class RetryState(TypedDict):
    message: str
    retry_count: int
    max_retries: int
    last_error: str | None
    processing_result: str | None


def retry_message_node(state: RetryState) -> RetryState:
    """Process message with retry logic"""
    if state.get("retry_count", 0) >= state.get("max_retries", 3):
        return {
            "last_error": "Max retries exceeded",
            "processing_result": None
        }
    
    try:
        result = process_message_with_retry(state["message"])
        return {
            "processing_result": result,
            "retry_count": 0,
            "last_error": None
        }
    except Exception as e:
        return {
            "last_error": str(e),
            "retry_count": state.get("retry_count", 0) + 1
        }
```

#### 3.2.2 Dead Letter Queue Pattern

```python
class DeadLetterState(TypedDict):
    message: str
    failure_reason: str
    failure_count: int
    dead_letter_queue: list | None


def dead_letter_handler(state: DeadLetterState) -> DeadLetterState:
    """Handle messages that cannot be processed"""
    if state.get("failure_count", 0) > 3:
        # Send to dead letter queue
        dead_letter_entry = {
            "message": state["message"],
            "reason": state["failure_reason"],
            "timestamp": datetime.now().isoformat()
        }
        
        return {
            "dead_letter_queue": [*state.get("dead_letter_queue", []), dead_letter_entry],
            "message": None,
            "failure_reason": None
        }
    return {}
```

### 3.3 Performance Optimization

#### 3.3.1 Message Batching

```python
class BatchState(TypedDict):
    messages: list
    batch_size: int
    processed_batches: list | None
    batch_processing_time: float | None


def batch_processor_node(state: BatchState) -> BatchState:
    """Process messages in batches"""
    messages = state["messages"]
    batch_size = state["batch_size"]
    
    # Process messages in batches
    processed_batches = []
    start_time = time.time()
    
    for i in range(0, len(messages), batch_size):
        batch = messages[i:i + batch_size]
        batch_result = process_batch(batch)
        processed_batches.append(batch_result)
    
    processing_time = time.time() - start_time
    
    return {
        "processed_batches": processed_batches,
        "batch_processing_time": processing_time
    }
```

#### 3.3.2 Message Caching

```python
class CacheState(TypedDict):
    message_key: str
    message_content: str
    cache_hit: bool
    cached_result: any | None
    cache_ttl: int


def cache_lookup_node(state: CacheState) -> CacheState:
    """Check cache before processing message"""
    message_key = state["message_key"]
    
    # Check cache
    cached_result = cache.get(message_key)
    
    if cached_result:
        return {
            "cache_hit": True,
            "cached_result": cached_result
        }
    
    # Process message if not in cache
    result = process_message(state["message_content"])
    cache.set(message_key, result, ttl=state["cache_ttl"])
    
    return {
        "cache_hit": False,
        "cached_result": result
    }
```

---

## Real-World Examples

### 4.1 Chat Application Message Flow

```python
class ChatState(TypedDict):
    user_message: str | None
    system_message: str | None
    assistant_response: str | None
    conversation_history: list | None
    message_metadata: dict | None
    processing_errors: list | None


def chat_input_node(state: ChatState) -> ChatState:
    """Handle user input message"""
    if state.get("user_message"):
        # Clean and validate user message
        cleaned_message = clean_user_input(state["user_message"])
        
        return {
            "user_message": cleaned_message,
            "message_metadata": {"role": "user", "timestamp": datetime.now().isoformat()}
        }
    return {}


def chat_processing_node(state: ChatState) -> ChatState:
    """Process chat message through various stages"""
    if state.get("user_message"):
        # Stage 1: Intent detection
        intent = detect_intent(state["user_message"])
        
        # Stage 2: Entity extraction
        entities = extract_entities(state["user_message"])
        
        # Stage 3: Context retrieval
        context = retrieve_context(intent, entities)
        
        return {
            "message_metadata": {
                **state.get("message_metadata", {}),
                "intent": intent,
                "entities": entities,
                "context": context
            }
        }
    return {}


def chat_response_node(state: ChatState) -> ChatState:
    """Generate assistant response"""
    if state.get("message_metadata"):
        # Generate response based on processed information
        response = generate_assistant_response(
            state.get("user_message"),
            state.get("message_metadata")
        )
        
        return {
            "assistant_response": response,
            "message_metadata": {
                **state.get("message_metadata", {}),
                "role": "assistant",
                "timestamp": datetime.now().isoformat()
            }
        }
    return {}
```

### 4.2 Data Pipeline Message Flow

```python
class PipelineState(TypedDict):
    source_data: any | None
    transformed_data: any | None
    validation_errors: list | None
    enriched_data: any | None
    storage_status: str | None
    processing_metrics: dict | None


def data_source_node(state: PipelineState) -> PipelineState:
    """Read data from source"""
    try:
        source_data = read_from_source()
        return {"source_data": source_data}
    except Exception as e:
        return {"validation_errors": [str(e)]}


def data_transformation_node(state: PipelineState) -> PipelineState:
    """Transform source data"""
    if state.get("source_data"):
        try:
            transformed = transform_data(state["source_data"])
            return {"transformed_data": transformed}
        except Exception as e:
            return {"validation_errors": [*state.get("validation_errors", []), str(e)]}
    return {}


def data_validation_node(state: PipelineState) -> PipelineState:
    """Validate transformed data"""
    if state.get("transformed_data"):
        try:
            is_valid, errors = validate_data(state["transformed_data"])
            if not is_valid:
                return {"validation_errors": errors}
        except Exception as e:
            return {"validation_errors": [*state.get("validation_errors", []), str(e)]}
    return {}


def data_enrichment_node(state: PipelineState) -> PipelineState:
    """Enrich data with additional information"""
    if state.get("transformed_data") and not state.get("validation_errors"):
        try:
            enriched = enrich_data(state["transformed_data"])
            return {"enriched_data": enriched}
        except Exception as e:
            return {"validation_errors": [*state.get("validation_errors", []), str(e)]}
    return {}


def data_storage_node(state: PipelineState) -> PipelineState:
    """Store processed data"""
    if state.get("enriched_data") and not state.get("validation_errors"):
        try:
            storage_status = store_data(state["enriched_data"])
            return {"storage_status": storage_status}
        except Exception as e:
            return {"validation_errors": [*state.get("validation_errors", []), str(e)]}
    return {}
```

---

## Testing Message Passing

### 5.1 Unit Testing Message Flow

```python
def test_message_passing():
    """Test message passing between nodes"""
    # Test simple message flow
    initial_state = {"message_content": "test message"}
    
    # Pass through nodes
    state_after_input = input_node(initial_state)
    state_after_processing = processing_node(state_after_input)
    state_after_response = response_node(state_after_processing)
    
    # Verify message flow
    assert state_after_input.get("processed_message") is not None
    assert state_after_processing.get("response_message") is not None
    assert state_after_response.get("response_message") == state_after_processing.get("response_message")


def test_error_handling():
    """Test error handling in message passing"""
    # Test error in processing
    error_state = {"message_content": ""}  # Invalid message
    
    try:
        processing_node(error_state)
        assert False, "Should have raised error"
    except Exception as e:
        assert "processing error" in str(e)


def test_message_validation():
    """Test message validation"""
    # Test valid message
    valid_state = {"message_content": "valid message"}
    is_valid, validated_state = validate_message(valid_state)
    assert is_valid is True
    assert validated_state.get("is_valid") is True
    
    # Test invalid message
    invalid_state = {"message_content": ""}
    is_valid, validated_state = validate_message(invalid_state)
    assert is_valid is False
    assert "required" in str(validated_state.get("processing_errors"))
```

### 5.2 Integration Testing Message Flow

```python
def test_complete_message_flow():
    """Test complete message flow through graph"""
    # Create complete graph for message processing
    graph = StateGraph(MessageFlowState)
    
    graph.add_node("input", input_node)
    graph.add_node("process", processing_node)
    graph.add_node("validate", validate_node)
    graph.add_node("respond", response_node)
    graph.add_node("error_handler", error_handler_node)
    
    graph.set_entry_point("input")
    
    # Add conditional edges for error handling
    graph.add_conditional_edges(
        "process",
        lambda state: state.get("processing_errors") is None,
        {"continue": "validate", "error": "error_handler"}
    )
    
    graph.add_conditional_edges(
        "validate",
        lambda state: state.get("validation_errors") is None,
        {"continue": "respond", "error": "error_handler"}
    )
    
    graph.add_edge("respond", END)
    graph.add_edge("error_handler", END)
    
    # Test with valid message
    valid_input = {"message_content": "test message"}
    result = graph.compile().invoke(valid_input)
    assert result.get("response_message") is not None
    
    # Test with invalid message
    invalid_input = {"message_content": ""}
    result = graph.compile().invoke(invalid_input)
    assert result.get("processing_errors") is not None
```

---

## Performance Considerations

### 6.1 Message Size Optimization

```python
def optimize_message_size(state: MessageFlowState) -> MessageFlowState:
    """Optimize message size for transmission"""
    message = state["message_content"]
    
    # Compress large messages
    if len(message) > 1000:
        compressed = compress_message(message)
        return {"message_content": compressed, "is_compressed": True}
    
    return {"is_compressed": False}


def decompress_message(state: MessageFlowState) -> MessageFlowState:
    """Decompress message if needed"""
    if state.get("is_compressed"):
        decompressed = decompress_message(state["message_content"])
        return {"message_content": decompressed, "is_compressed": False}
    return {}
```

### 6.2 Message Queue Management

```python
def manage_message_queue(state: MessageFlowState) -> MessageFlowState:
    """Manage message queue for performance"""
    queue = state.get("message_queue", [])
    
    # Process messages in batches
    batch_size = 100
    processed = 0
    
    while processed < len(queue) and processed < batch_size:
        message = queue.pop(0)
        process_message(message)
        processed += 1
    
    return {"message_queue": queue, "processed_count": processed}
```

---

## Security Considerations

### 7.1 Message Sanitization

```python
def sanitize_message(state: MessageFlowState) -> MessageFlowState:
    """Sanitize message to prevent security issues"""
    message = state["message_content"]
    
    # Remove potentially dangerous content
    sanitized = remove_script_tags(message)
    sanitized = escape_html(sanitized)
    sanitized = remove_sql_injection(sanitized)
    
    return {"message_content": sanitized, "is_sanitized": True}
```

### 7.2 Message Encryption

```python
def encrypt_message(state: MessageFlowState) -> MessageFlowState:
    """Encrypt sensitive messages"""
    message = state["message_content"]
    
    if contains_sensitive_data(message):
        encrypted = encrypt(message)
        return {
            "message_content": encrypted,
            "is_encrypted": True,
            "encryption_metadata": {
                "algorithm": "aes-256",
                "timestamp": datetime.now().isoformat()
            }
        }
    return {"is_encrypted": False}
```

---

## Summary

This comprehensive guide covers:

| Topic | Key Points |
|-------|------------|
| **Core Concepts** | State-based communication, event-driven messaging |
| **Advanced Patterns** | Message broadcasting, routing, transformation |
| **Best Practices** | State management, error handling, performance optimization |
| **Real-World Examples** | Chat applications, data pipelines |
| **Testing** | Unit and integration testing strategies |
| **Performance** | Message size optimization, queue management |
| **Security** | Message sanitization, encryption |

---

*Document Version: 1.0*
*Last Updated: January 2026*

---

## Next Steps

After implementing message passing, explore:
- [State Persistence Best Practices](../state_persistence.md)
- [Error Handling and Recovery Patterns](../error_handling.md)
- [Advanced Tool Usage](../tools.md)
- [Performance Optimization](../performance.md)