# LangGraph Error Handling and Recovery Patterns

## Overview

This guide covers comprehensive error handling and recovery patterns for LangGraph applications, including transient error handling, retry strategies, circuit breakers, fallback mechanisms, and production-grade error recovery.

---

## Core Error Handling Concepts

### 1.1 Error Classification

Classify errors to apply appropriate handling strategies.

#### 1.1.1 Error Types

```python
from enum import Enum
from typing import TypedDict, Optional, Any

class ErrorType(Enum):
    TRANSIENT = "transient"        # Temporary issues (network, rate limits)
    PERMANENT = "permanent"        # Configuration or data errors
    RECOVERABLE = "recoverable"    # Can be fixed by retrying or alternative
    UNRECOVERABLE = "unrecoverable" # System failures, invalid state
    USER_ERROR = "user_error"      # Invalid input or user action
    SYSTEM_ERROR = "system_error"  # Infrastructure or dependency failures

class ErrorContext(TypedDict):
    error_type: ErrorType
    error_message: str
    error_details: dict | None
    timestamp: str
    retry_count: int
    max_retries: int
    retry_delay: float | None
    fallback_used: bool
    recovery_attempted: bool

class ErrorState(TypedDict):
    error: ErrorContext | None
    error_history: list
    last_error_time: str | None
    recovery_attempts: int
    max_recovery_attempts: int
    is_recovered: bool
    recovery_timestamp: str | None
```

#### 1.1.2 Error Classification Function

```python
def classify_error(error: Exception, context: dict = None) -> ErrorContext:
    """Classify error and provide context for handling"""
    error_type = ErrorType.UNRECOVERABLE
    error_message = str(error)
    error_details = {}
    
    # Classify based on error type
    if isinstance(error, (ConnectionError, TimeoutError, requests.exceptions.RequestException)):
        error_type = ErrorType.TRANSIENT
        error_details["network_issue"] = True
        
    elif isinstance(error, (ValueError, KeyError, TypeError)):
        error_type = ErrorType.USER_ERROR
        error_details["validation_issue"] = True
        
    elif isinstance(error, (RuntimeError, NotImplementedError)):
        error_type = ErrorType.PERMANENT
        error_details["implementation_issue"] = True
        
    elif isinstance(error, (MemoryError, SystemError)):
        error_type = ErrorType.SYSTEM_ERROR
        error_details["system_issue"] = True
        
    # Add context if provided
    if context:
        error_details["context"] = context
    
    return {
        "error_type": error_type,
        "error_message": error_message,
        "error_details": error_details,
        "timestamp": datetime.now().isoformat(),
        "retry_count": 0,
        "max_retries": 3,
        "retry_delay": 1.0,
        "fallback_used": False,
        "recovery_attempted": False
    }
```

### 1.2 Basic Error Handling Pattern

Implement error handling in nodes with proper classification and recovery.

#### 1.2.1 Try-Catch with Error Classification

```python
class SafeState(TypedDict):
    input: str
    result: Any | None
    error: ErrorContext | None
    error_history: list
    retry_count: int
    max_retries: int


def safe_node(state: SafeState) -> SafeState:
    """Node with comprehensive error handling"""
    try:
        # Perform operation
        result = perform_risky_operation(state["input"])
        
        return {
            "result": result,
            "error": None,
            "error_history": state.get("error_history", []),
            "retry_count": 0
        }
        
    except Exception as e:
        # Classify error
        error_context = classify_error(e, context={"input": state["input"]})
        
        # Update error history
        error_history = [*state.get("error_history", []), error_context]
        
        # Update retry count
        retry_count = state.get("retry_count", 0) + 1
        
        # Update error context with retry info
        error_context["retry_count"] = retry_count
        error_context["max_retries"] = state.get("max_retries", 3)
        
        return {
            "result": None,
            "error": error_context,
            "error_history": error_history,
            "retry_count": retry_count
        }
```

#### 1.2.2 Error Recovery Pattern

```python
def recovery_node(state: SafeState) -> SafeState:
    """Node that attempts recovery from errors"""
    error = state.get("error")
    
    if not error:
        return state  # No error to recover from
    
    # Check if we should attempt recovery
    if error["retry_count"] > error["max_retries"]:
        return state  # Max retries reached
    
    # Attempt recovery based on error type
    try:
        if error["error_type"] == ErrorType.TRANSIENT:
            # Retry with backoff
            retry_delay = error["retry_delay"] * (2 ** (error["retry_count"] - 1))
            time.sleep(retry_delay)
            
            return {
                "result": perform_risky_operation(state["input"]),
                "error": None,
                "error_history": state["error_history"],
                "retry_count": 0
            }
            
        elif error["error_type"] == ErrorType.RECOVERABLE:
            # Use fallback
            fallback_result = use_fallback(state["input"])
            
            return {
                "result": fallback_result,
                "error": {**error, "fallback_used": True},
                "error_history": state["error_history"],
                "retry_count": 0
            }
            
        elif error["error_type"] == ErrorType.USER_ERROR:
            # Return user-friendly error
            return {
                "result": None,
                "error": {**error, "user_friendly": True},
                "error_history": state["error_history"],
                "retry_count": 0
            }
            
    except Exception as recovery_error:
        # Recovery attempt failed
        recovery_error_context = classify_error(recovery_error, context={"recovery_attempt": True})
        
        return {
            "result": None,
            "error": {**error, "recovery_failed": True},
            "error_history": [*state["error_history"], recovery_error_context],
            "retry_count": state["retry_count"]
        }
    
    return state
```

---

## Advanced Error Handling Patterns

### 2.1 Retry Strategies

Implement sophisticated retry mechanisms with exponential backoff and jitter.

#### 2.1.1 Exponential Backoff with Jitter

```python
import random
import time
from typing import Callable, Optional

class RetryStrategy:
    def __init__(self, max_retries: int = 3, base_delay: float = 1.0, max_delay: float = 30.0, jitter: float = 0.1):
        self.max_retries = max_retries
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.jitter = jitter
    
    def calculate_delay(self, retry_count: int) -> float:
        """Calculate delay with exponential backoff and jitter"""
        if retry_count >= self.max_retries:
            return self.max_delay
        
        # Exponential backoff
        delay = self.base_delay * (2 ** retry_count)
        
        # Add jitter
        jitter_amount = delay * self.jitter * random.uniform(-1, 1)
        delay += jitter_amount
        
        # Cap at max delay
        return min(delay, self.max_delay)
    
    def should_retry(self, retry_count: int, error_type: ErrorType) -> bool:
        """Determine if we should retry"""
        if retry_count >= self.max_retries:
            return False
        
        # Only retry transient and recoverable errors
        return error_type in [ErrorType.TRANSIENT, ErrorType.RECOVERABLE]

class RetryNode:
    def __init__(self, strategy: RetryStrategy = None):
        self.strategy = strategy or RetryStrategy()
    
    def execute_with_retry(self, operation: Callable, *args, **kwargs) -> tuple[Any, Optional[ErrorContext]]:
        """Execute operation with retry logic"""
        retry_count = 0
        
        while retry_count <= self.strategy.max_retries:
            try:
                result = operation(*args, **kwargs)
                return result, None
                
            except Exception as e:
                error_context = classify_error(e)
                
                # Check if we should retry
                if not self.strategy.should_retry(retry_count, error_context["error_type"]):
                    return None, error_context
                
                # Calculate delay
                delay = self.strategy.calculate_delay(retry_count)
                
                # Update error context with retry info
                error_context["retry_count"] = retry_count
                error_context["retry_delay"] = delay
                
                # Wait before retrying
                time.sleep(delay)
                
                retry_count += 1
        
        # Return last error if all retries failed
        return None, error_context

# Usage in node
def retry_node(state: SafeState) -> SafeState:
    """Node with retry strategy"""
    retry_strategy = RetryStrategy(max_retries=5, base_delay=0.5, max_delay=10.0, jitter=0.2)
    retry_node = RetryNode(retry_strategy)
    
    result, error = retry_node.execute_with_retry(
        perform_risky_operation,
        state["input"]
    )
    
    if error:
        return {
            "result": None,
            "error": error,
            "error_history": [*state.get("error_history", []), error],
            "retry_count": retry_strategy.max_retries
        }
    
    return {
        "result": result,
        "error": None,
        "error_history": state.get("error_history", []),
        "retry_count": 0
    }
```

#### 2.1.2 Circuit Breaker Pattern

```python
import time
from typing import Optional, Callable, Any

class CircuitBreaker:
    def __init__(self, failure_threshold: int = 5, recovery_timeout: float = 60.0):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.failure_count = 0
        self.state = "CLOSED"  # CLOSED, OPEN, HALF_OPEN
        self.last_failure_time = None
    
    def call(self, operation: Callable, *args, **kwargs) -> tuple[Any, Optional[ErrorContext]]:
        """Call operation with circuit breaker protection"""
        current_time = time.time()
        
        # Check circuit state
        if self.state == "OPEN":
            # Check if recovery timeout has passed
            if self.last_failure_time and (current_time - self.last_failure_time) > self.recovery_timeout:
                self.state = "HALF_OPEN"
            else:
                # Circuit is open, fail fast
                error_context = {
                    "error_type": ErrorType.SYSTEM_ERROR,
                    "error_message": "Circuit breaker is OPEN",
                    "error_details": {"circuit_state": "OPEN"},
                    "timestamp": datetime.now().isoformat(),
                    "fallback_used": True
                }
                return None, error_context
        
        try:
            # Call the operation
            result = operation(*args, **kwargs)
            
            # If successful, reset failure count if in HALF_OPEN state
            if self.state == "HALF_OPEN":
                self.state = "CLOSED"
                self.failure_count = 0
            
            return result, None
            
        except Exception as e:
            error_context = classify_error(e)
            
            # Increment failure count
            self.failure_count += 1
            self.last_failure_time = current_time
            
            # Open circuit if failure threshold is reached
            if self.failure_count >= self.failure_threshold:
                self.state = "OPEN"
            
            return None, error_context

class CircuitBreakerNode:
    def __init__(self, failure_threshold: int = 5, recovery_timeout: float = 60.0):
        self.circuit_breaker = CircuitBreaker(failure_threshold, recovery_timeout)
    
    def execute_with_circuit_breaker(self, operation: Callable, *args, **kwargs) -> SafeState:
        """Execute operation with circuit breaker protection"""
        result, error = self.circuit_breaker.call(operation, *args, **kwargs)
        
        if error:
            return {
                "result": None,
                "error": error,
                "error_history": [],
                "retry_count": 0
            }
        
        return {
            "result": result,
            "error": None,
            "error_history": [],
            "retry_count": 0
        }

# Usage in node
def circuit_breaker_node(state: SafeState) -> SafeState:
    """Node with circuit breaker protection"""
    circuit_breaker_node = CircuitBreakerNode(failure_threshold=3, recovery_timeout=30.0)
    
    result_state = circuit_breaker_node.execute_with_circuit_breaker(
        perform_risky_operation,
        state["input"]
    )
    
    return result_state
```

### 2.2 Fallback Mechanisms

Implement fallback strategies for graceful degradation.

#### 2.2.1 Multi-Level Fallback Pattern

```python
class FallbackStrategy:
    def __init__(self):
        self.fallback_levels = []
    
    def add_fallback(self, fallback_function: Callable, priority: int = 0):
        """Add fallback function with priority"""
        self.fallback_levels.append({
            "function": fallback_function,
            "priority": priority
        })
        
        # Sort by priority (lower number = higher priority)
        self.fallback_levels.sort(key=lambda x: x["priority"])
    
    def get_fallback(self, error_context: ErrorContext) -> Optional[Callable]:
        """Get appropriate fallback based on error context"""
        for fallback in self.fallback_levels:
            # Check if fallback is applicable for this error type
            if self.is_fallback_applicable(fallback["function"], error_context):
                return fallback["function"]
        
        return None
    
    def is_fallback_applicable(self, fallback_function: Callable, error_context: ErrorContext) -> bool:
        """Check if fallback is applicable for error type"""
        # This would be implemented based on fallback function metadata
        # For now, assume all fallbacks are applicable
        return True

class FallbackNode:
    def __init__(self):
        self.fallback_strategy = FallbackStrategy()
    
    def execute_with_fallback(self, operation: Callable, *args, **kwargs) -> tuple[Any, Optional[ErrorContext]]:
        """Execute operation with fallback mechanism"""
        try:
            # Try primary operation
            result = operation(*args, **kwargs)
            return result, None
            
        except Exception as e:
            error_context = classify_error(e)
            
            # Try fallbacks
            fallback_function = self.fallback_strategy.get_fallback(error_context)
            
            if fallback_function:
                try:
                    fallback_result = fallback_function(*args, **kwargs)
                    error_context["fallback_used"] = True
                    return fallback_result, error_context
                    
                except Exception as fallback_error:
                    fallback_error_context = classify_error(fallback_error)
                    return None, fallback_error_context
            
            # No fallback available
            return None, error_context

# Define fallback functions
def fallback_to_cache(input_data: str) -> str:
    """Fallback to cached data"""
    return cache.get(input_data, "default_cached_value")


def fallback_to_default(input_data: str) -> str:
    """Fallback to default value"""
    return f"default_value_for_{input_data}"


def fallback_to_alternative_service(input_data: str) -> str:
    """Fallback to alternative service"""
    return alternative_service.call(input_data)

# Usage in node
def fallback_node(state: SafeState) -> SafeState:
    """Node with multi-level fallback"""
    fallback_node = FallbackNode()
    
    # Configure fallback hierarchy
    fallback_node.fallback_strategy.add_fallback(fallback_to_cache, priority=1)
    fallback_node.fallback_strategy.add_fallback(fallback_to_default, priority=2)
    fallback_node.fallback_strategy.add_fallback(fallback_to_alternative_service, priority=3)
    
    result, error = fallback_node.execute_with_fallback(
        perform_risky_operation,
        state["input"]
    )
    
    if error:
        return {
            "result": None,
            "error": error,
            "error_history": [],
            "retry_count": 0
        }
    
    return {
        "result": result,
        "error": error,
        "error_history": [],
        "retry_count": 0
    }
```

#### 2.2.2 Graceful Degradation Pattern

```python
class GracefulDegradation:
    def __init__(self, degradation_levels: dict):
        self.degradation_levels = degradation_levels
        self.current_level = 0
    
    def should_degrade(self, error_context: ErrorContext) -> bool:
        """Determine if we should degrade based on error"""
        # Degrade for persistent or system errors
        return error_context["error_type"] in [ErrorType.PERMANENT, ErrorType.SYSTEM_ERROR]
    
    def degrade(self) -> None:
        """Move to next degradation level"""
        if self.current_level < len(self.degradation_levels) - 1:
            self.current_level += 1
    
    def get_degradation_handler(self) -> Callable:
        """Get handler for current degradation level"""
        return self.degradation_levels[self.current_level]

class DegradationNode:
    def __init__(self, degradation_levels: dict):
        self.degradation = GracefulDegradation(degradation_levels)
    
    def execute_with_degradation(self, operation: Callable, *args, **kwargs) -> tuple[Any, Optional[ErrorContext]]:
        """Execute operation with graceful degradation"""
        try:
            # Try primary operation
            result = operation(*args, **kwargs)
            return result, None
            
        except Exception as e:
            error_context = classify_error(e)
            
            # Check if we should degrade
            if self.degradation.should_degrade(error_context):
                self.degradation.degrade()
                degradation_handler = self.degradation.get_degradation_handler()
                
                try:
                    degraded_result = degradation_handler(*args, **kwargs)
                    error_context["degraded": True]
                    error_context["degradation_level"] = self.degradation.current_level
                    return degraded_result, error_context
                    
                except Exception as degradation_error:
                    degradation_error_context = classify_error(degradation_error)
                    return None, degradation_error_context
            
            # No degradation, return original error
            return None, error_context

# Define degradation levels
def full_service(input_data: str) -> str:
    """Full service with all features"""
    return perform_full_operation(input_data)


def reduced_service(input_data: str) -> str:
    """Reduced service with limited features"""
    return perform_reduced_operation(input_data)


def minimal_service(input_data: str) -> str:
    """Minimal service with basic functionality"""
    return perform_minimal_operation(input_data)


def cached_service(input_data: str) -> str:
    """Service using cached data"""
    return cache.get(input_data, "cached_default")

# Usage in node
def degradation_node(state: SafeState) -> SafeState:
    """Node with graceful degradation"""
    degradation_levels = {
        0: full_service,
        1: reduced_service,
        2: minimal_service,
        3: cached_service
    }
    
    degradation_node = DegradationNode(degradation_levels)
    
    result, error = degradation_node.execute_with_degradation(
        full_service,
        state["input"]
    )
    
    if error:
        return {
            "result": None,
            "error": error,
            "error_history": [],
            "retry_count": 0
        }
    
    return {
        "result": result,
        "error": error,
        "error_history": [],
        "retry_count": 0
    }
```

---

## Recovery Patterns

### 3.1 State Recovery

Recover from errors by restoring previous valid state.

#### 3.1.1 Checkpoint-Based Recovery

```python
class StateRecovery:
    def __init__(self, checkpointer):
        self.checkpointer = checkpointer
        self.max_recovery_attempts = 3
    
    def attempt_recovery(self, state: SafeState, config: dict) -> tuple[SafeState, bool]:
        """Attempt recovery using checkpoints"""
        error = state.get("error")
        recovery_attempts = state.get("recovery_attempts", 0)
        
        if not error or recovery_attempts >= self.max_recovery_attempts:
            return state, False  # No recovery needed or max attempts reached
        
        try:
            # Get last checkpoint
            checkpoint = self.checkpointer.get(config)
            if not checkpoint:
                return state, False  # No checkpoint available
            
            # Restore state from checkpoint
            recovered_state = checkpoint.state
            
            # Mark as recovered
            recovered_state["is_recovered"] = True
            recovered_state["recovery_timestamp"] = datetime.now().isoformat()
            recovered_state["recovery_attempts"] = recovery_attempts + 1
            
            return recovered_state, True
            
        except Exception as recovery_error:
            # Recovery attempt failed
            recovery_error_context = classify_error(recovery_error, context={"recovery_attempt": True})
            
            return {
                "result": None,
                "error": recovery_error_context,
                "error_history": [*state.get("error_history", []), recovery_error_context],
                "retry_count": state.get("retry_count", 0),
                "recovery_attempts": recovery_attempts + 1,
                "is_recovered": False
            }, False

class RecoveryNode:
    def __init__(self, checkpointer):
        self.state_recovery = StateRecovery(checkpointer)
    
    def execute_with_recovery(self, operation: Callable, *args, **kwargs) -> tuple[Any, Optional[ErrorContext], bool]:
        """Execute operation with recovery mechanism"""
        result, error = operation(*args, **kwargs)
        
        if error:
            # Attempt recovery
            config = kwargs.get("config", {})
            recovered_state, recovery_successful = self.state_recovery.attempt_recovery(
                {"result": result, "error": error, "error_history": [], "retry_count": 0},
                config
            )
            
            if recovery_successful:
                return recovered_state["result"], None, True
            
        return result, error, False

# Usage in node
def recovery_node(state: SafeState) -> SafeState:
    """Node with state recovery"""
    # This would be part of a larger recovery system
    # For demonstration, assume we have access to checkpointer and config
    checkpointer = get_checkpointer()
    config = get_config()
    
    recovery_node = RecoveryNode(checkpointer)
    
    result, error, recovery_successful = recovery_node.execute_with_recovery(
        perform_risky_operation,
        state["input"],
        config=config
    )
    
    if error:
        return {
            "result": None,
            "error": error,
            "error_history": [],
            "retry_count": 0,
            "recovery_successful": recovery_successful
        }
    
    return {
        "result": result,
        "error": None,
        "error_history": [],
        "retry_count": 0,
        "recovery_successful": recovery_successful
    }
```

#### 3.1.2 State Rollback Pattern

```python
class StateRollback:
    def __init__(self, max_rollbacks: int = 3):
        self.max_rollbacks = max_rollbacks
        self.rollback_history = []
    
    def save_rollback_point(self, state: dict) -> None:
        """Save state as rollback point"""
        # Keep only last few rollback points
        if len(self.rollback_history) >= self.max_rollbacks:
            self.rollback_history.pop(0)
        
        self.rollback_history.append({
            "state": state.copy(),
            "timestamp": datetime.now().isoformat()
        })
    
    def rollback(self, error_context: ErrorContext) -> tuple[Optional[dict], Optional[ErrorContext]]:
        """Rollback to previous state"""
        if not self.rollback_history:
            return None, {
                "error_type": ErrorType.UNRECOVERABLE,
                "error_message": "No rollback points available",
                "error_details": {"rollback_history": "empty"},
                "timestamp": datetime.now().isoformat(),
                "rollback_failed": True
            }
        
        # Get last rollback point
        last_rollback = self.rollback_history.pop()
        
        return last_rollback["state"], None

class RollbackNode:
    def __init__(self, max_rollbacks: int = 3):
        self.state_rollback = StateRollback(max_rollbacks)
    
    def execute_with_rollback(self, operation: Callable, *args, **kwargs) -> tuple[Any, Optional[ErrorContext]]:
        """Execute operation with rollback protection"""
        try:
            # Save rollback point
            current_state = kwargs.get("current_state", {})
            self.state_rollback.save_rollback_point(current_state)
            
            # Execute operation
            result = operation(*args, **kwargs)
            return result, None
            
        except Exception as e:
            error_context = classify_error(e)
            
            # Attempt rollback
            rollback_state, rollback_error = self.state_rollback.rollback(error_context)
            
            if rollback_state:
                # Return to previous state
                error_context["rolled_back"] = True
                error_context["rollback_timestamp"] = datetime.now().isoformat()
                return rollback_state, error_context
            
            # Rollback failed, return original error
            return None, error_context

# Usage in node
def rollback_node(state: SafeState) -> SafeState:
    """Node with rollback protection"""
    rollback_node = RollbackNode(max_rollbacks=5)
    
    result, error = rollback_node.execute_with_rollback(
        perform_risky_operation,
        state["input"],
        current_state=state
    )
    
    if error:
        return {
            "result": None,
            "error": error,
            "error_history": [],
            "retry_count": 0
        }
    
    return {
        "result": result,
        "error": None,
        "error_history": [],
        "retry_count": 0
    }
```

### 3.2 Error Recovery Strategies

Implement different recovery strategies based on error context.

#### 3.2.1 Adaptive Recovery

```python
class AdaptiveRecovery:
    def __init__(self):
        self.recovery_strategies = {}
        self.strategy_history = []
    
    def register_strategy(self, error_type: ErrorType, strategy: Callable):
        """Register recovery strategy for error type"""
        self.recovery_strategies[error_type] = strategy
    
    def get_strategy(self, error_context: ErrorContext) -> Optional[Callable]:
        """Get appropriate recovery strategy"""
        error_type = error_context["error_type"]
        
        # Check if we have a registered strategy
        if error_type in self.recovery_strategies:
            return self.recovery_strategies[error_type]
        
        # Default strategy for unknown errors
        return self.default_recovery_strategy
    
    def default_recovery_strategy(self, error_context: ErrorContext, *args, **kwargs) -> Any:
        """Default recovery strategy"""
        # Simple retry with exponential backoff
        retry_count = error_context.get("retry_count", 0)
        base_delay = 1.0
        delay = base_delay * (2 ** retry_count)
        
        time.sleep(delay)
        
        # Retry the operation
        return perform_risky_operation(*args, **kwargs)
    
    def execute_with_adaptive_recovery(self, operation: Callable, *args, **kwargs) -> tuple[Any, Optional[ErrorContext]]:
        """Execute operation with adaptive recovery"""
        try:
            result = operation(*args, **kwargs)
            return result, None
            
        except Exception as e:
            error_context = classify_error(e)
            
            # Get appropriate recovery strategy
            strategy = self.get_strategy(error_context)
            
            if strategy:
                try:
                    # Execute recovery strategy
                    recovered_result = strategy(error_context, *args, **kwargs)
                    error_context["recovery_successful"] = True
                    error_context["recovery_strategy"] = strategy.__name__
                    return recovered_result, error_context
                    
                except Exception as recovery_error:
                    recovery_error_context = classify_error(recovery_error)
                    return None, recovery_error_context
            
            # No recovery strategy available
            return None, error_context

# Register recovery strategies
adaptive_recovery = AdaptiveRecovery()


def transient_recovery(error_context: ErrorContext, *args, **kwargs):
    """Recovery strategy for transient errors"""
    # Use circuit breaker for transient errors
    circuit_breaker = CircuitBreaker(failure_threshold=3, recovery_timeout=30.0)
    return circuit_breaker.call(perform_risky_operation, *args, **kwargs)


def permanent_recovery(error_context: ErrorContext, *args, **kwargs):
    """Recovery strategy for permanent errors"""
    # Use fallback for permanent errors
    return use_fallback(*args, **kwargs)


def user_error_recovery(error_context: ErrorContext, *args, **kwargs):
    """Recovery strategy for user errors"""
    # Return user-friendly error message
    return f"Error: {error_context[\"error_message\"]}. Please check your input and try again."

# Register strategies
adaptive_recovery.register_strategy(ErrorType.TRANSIENT, transient_recovery)
adaptive_recovery.register_strategy(ErrorType.PERMANENT, permanent_recovery)
adaptive_recovery.register_strategy(ErrorType.USER_ERROR, user_error_recovery)

# Usage in node
def adaptive_recovery_node(state: SafeState) -> SafeState:
    """Node with adaptive recovery"""
    result, error = adaptive_recovery.execute_with_adaptive_recovery(
        perform_risky_operation,
        state["input"]
    )
    
    if error:
        return {
            "result": None,
            "error": error,
            "error_history": [],
            "retry_count": 0
        }
    
    return {
        "result": result,
        "error": None,
        "error_history": [],
        "retry_count": 0
    }
```

#### 3.2.2 Multi-Stage Recovery

```python
class MultiStageRecovery:
    def __init__(self, stages: list):
        self.stages = stages
        self.current_stage = 0
    
    def execute_recovery(self, error_context: ErrorContext, *args, **kwargs) -> tuple[Any, Optional[ErrorContext], bool]:
        """Execute multi-stage recovery"""
        while self.current_stage < len(self.stages):
            stage = self.stages[self.current_stage]
            
            try:
                # Execute recovery stage
                result = stage["function"](error_context, *args, **kwargs)
                
                # If successful, return result
                if result is not None:
                    error_context["recovery_stage"] = self.current_stage
                    error_context["recovery_successful"] = True
                    error_context["recovery_strategy"] = stage["name"]
                    return result, error_context, True
                
            except Exception as stage_error:
                stage_error_context = classify_error(stage_error)
                error_context["recovery_stage_errors"].append(stage_error_context)
            
            # Move to next stage
            self.current_stage += 1
        
        # All stages failed
        error_context["all_recovery_stages_failed"] = True
        return None, error_context, False

# Define recovery stages
def stage_1_retry(error_context: ErrorContext, *args, **kwargs):
    """First recovery stage: simple retry"""
    retry_count = error_context.get("retry_count", 0)
    if retry_count < 3:
        time.sleep(1.0 * (2 ** retry_count))
        return perform_risky_operation(*args, **kwargs)
    return None


def stage_2_fallback(error_context: ErrorContext, *args, **kwargs):
    """Second recovery stage: fallback"""
    return use_fallback(*args, **kwargs)


def stage_3_degradation(error_context: ErrorContext, *args, **kwargs):
    """Third recovery stage: graceful degradation"""
    return degrade_service(*args, **kwargs)


def stage_4_notification(error_context: ErrorContext, *args, **kwargs):
    """Fourth recovery stage: notify and fail gracefully"""
    notify_error(error_context)
    return f"Service temporarily unavailable. Error: {error_context[\"error_message\"]}"

# Create multi-stage recovery
multi_stage_recovery = MultiStageRecovery([
    {"name": "retry", "function": stage_1_retry},
    {"name": "fallback", "function": stage_2_fallback},
    {"name": "degradation", "function": stage_3_degradation},
    {"name": "notification", "function": stage_4_notification}
])

# Usage in node
def multi_stage_recovery_node(state: SafeState) -> SafeState:
    """Node with multi-stage recovery"""
    result, error, recovery_successful = multi_stage_recovery.execute_recovery(
        state.get("error", {"error_type": ErrorType.UNRECOVERABLE}),
        state["input"]
    )
    
    if error:
        return {
            "result": None,
            "error": error,
            "error_history": [],
            "retry_count": 0,
            "recovery_successful": recovery_successful
        }
    
    return {
        "result": result,
        "error": error,
        "error_history": [],
        "retry_count": 0,
        "recovery_successful": recovery_successful
    }
```

---

## Production Considerations

### 4.1 Error Monitoring and Alerting

```python
class ErrorMonitor:
    def __init__(self, alert_thresholds: dict):
        self.alert_thresholds = alert_thresholds
        self.error_counts = {}
        self.error_rates = {}
        self.last_alert_time = {}
    
    def record_error(self, error_context: ErrorContext) -> None:
        """Record error occurrence"""
        error_type = error_context["error_type"]
        timestamp = error_context["timestamp"]
        
        # Update error counts
        self.error_counts[error_type] = self.error_counts.get(error_type, 0) + 1
        
        # Calculate error rate
        time_window = 60  # seconds
        current_time = time.time()
        
        # Keep track of error timestamps for rate calculation
        if error_type not in self.error_rates:
            self.error_rates[error_type] = []
        
        self.error_rates[error_type].append(current_time)
        
        # Remove old timestamps
        self.error_rates[error_type] = [
            t for t in self.error_rates[error_type] if current_time - t < time_window
        ]
        
        # Check if we should alert
        error_rate = len(self.error_rates[error_type]) / time_window
        
        if error_rate > self.alert_thresholds.get(error_type, 0.1):
            if (current_time - self.last_alert_time.get(error_type, 0)) > 300:  # 5 minutes
                self.send_alert(error_context, error_rate)
                self.last_alert_time[error_type] = current_time
    
    def send_alert(self, error_context: ErrorContext, error_rate: float) -> None:
        """Send alert for high error rate"""
        alert_message = f"High {error_context[\"error_type\"].value} error rate: {error_rate:.2f} errors/sec"
        
        # Send alert via configured channels (email, slack, etc.)
        print(f"ALERT: {alert_message}")
        
        # Log alert
        with open("error_alerts.log", "a") as f:
            f.write(f"{datetime.now().isoformat()} - {alert_message}\n")

class ErrorMonitoringNode:
    def __init__(self, alert_thresholds: dict):
        self.error_monitor = ErrorMonitor(alert_thresholds)
    
    def execute_with_monitoring(self, operation: Callable, *args, **kwargs) -> tuple[Any, Optional[ErrorContext]]:
        """Execute operation with error monitoring"""
        try:
            result = operation(*args, **kwargs)
            return result, None
            
        except Exception as e:
            error_context = classify_error(e)
            
            # Record error for monitoring
            self.error_monitor.record_error(error_context)
            
            return None, error_context

# Usage in node
def monitoring_node(state: SafeState) -> SafeState:
    """Node with error monitoring"""
    alert_thresholds = {
        ErrorType.TRANSIENT: 0.5,      # 0.5 errors/sec
        ErrorType.PERMANENT: 0.1,      # 0.1 errors/sec  
        ErrorType.SYSTEM_ERROR: 0.05,  # 0.05 errors/sec
        ErrorType.UNRECOVERABLE: 0.01  # 0.01 errors/sec
    }
    
    monitoring_node = ErrorMonitoringNode(alert_thresholds)
    
    result, error = monitoring_node.execute_with_monitoring(
        perform_risky_operation,
        state["input"]
    )
    
    if error:
        return {
            "result": None,
            "error": error,
            "error_history": [],
            "retry_count": 0
        }
    
    return {
        "result": result,
        "error": None,
        "error_history": [],
        "retry_count": 0
    }
```

### 4.2 Error Reporting and Logging

```python
class ErrorReporter:
    def __init__(self, log_level: str = "INFO"):
        self.log_level = log_level
        self.error_log_file = "application_errors.log"
        self.error_summary_file = "error_summary.log"
    
    def log_error(self, error_context: ErrorContext, additional_info: dict = None) -> None:
        """Log error with context"""
        log_entry = {
            "timestamp": error_context["timestamp"],
            "error_type": error_context["error_type"].value,
            "error_message": error_context["error_message"],
            "error_details": error_context["error_details"],
            "retry_count": error_context.get("retry_count", 0),
            "max_retries": error_context.get("max_retries", 0),
            "fallback_used": error_context.get("fallback_used", False),
            "recovery_successful": error_context.get("recovery_successful", False),
            "context": additional_info
        }
        
        # Write to error log
        with open(self.error_log_file, "a") as f:
            f.write(json.dumps(log_entry) + "\n")
        
        # Update error summary
        self.update_error_summary(log_entry)
    
    def update_error_summary(self, log_entry: dict) -> None:
        """Update error summary statistics"""
        summary = self.load_error_summary()
        
        error_type = log_entry["error_type"]
        
        if error_type not in summary:
            summary[error_type] = {
                "count": 0,
                "last_occurrence": log_entry["timestamp"],
                "total_retries": 0,
                "successful_recoveries": 0,
                "failed_recoveries": 0
            }
        
        summary[error_type]["count"] += 1
        summary[error_type]["last_occurrence"] = log_entry["timestamp"]
        summary[error_type]["total_retries"] += log_entry["retry_count"]
        
        if log_entry.get("recovery_successful"):
            summary[error_type]["successful_recoveries"] += 1
        else:
            summary[error_type]["failed_recoveries"] += 1
        
        # Save summary
        with open(self.error_summary_file, "w") as f:
            f.write(json.dumps(summary, indent=2))
    
    def load_error_summary(self) -> dict:
        """Load error summary from file"""
        try:
            with open(self.error_summary_file, "r") as f:
                return json.load(f)
        except FileNotFoundError:
            return {}

class ErrorReportingNode:
    def __init__(self, reporter: ErrorReporter):
        self.reporter = reporter
    
    def execute_with_reporting(self, operation: Callable, *args, **kwargs) -> tuple[Any, Optional[ErrorContext]]:
        """Execute operation with error reporting"""
        try:
            result = operation(*args, **kwargs)
            return result, None
            
        except Exception as e:
            error_context = classify_error(e)
            
            # Report error
            self.reporter.log_error(error_context, additional_info={"operation": operation.__name__})
            
            return None, error_context

# Usage in node
def reporting_node(state: SafeState) -> SafeState:
    """Node with error reporting"""
    reporter = ErrorReporter(log_level="INFO")
    reporting_node = ErrorReportingNode(reporter)
    
    result, error = reporting_node.execute_with_reporting(
        perform_risky_operation,
        state["input"]
    )
    
    if error:
        return {
            "result": None,
            "error": error,
            "error_history": [],
            "retry_count": 0
        }
    
    return {
        "result": result,
        "error": None,
        "error_history": [],
        "retry_count": 0
    }
```

---

## Testing Error Handling

### 5.1 Unit Testing Error Scenarios

```python
def test_transient_error_handling():
    """Test handling of transient errors"""
    # Create node with retry strategy
    retry_strategy = RetryStrategy(max_retries=3, base_delay=0.1)
    retry_node = RetryNode(retry_strategy)
    
    # Test transient error that succeeds on retry
    def transient_operation(input_data):
        if transient_operation.retry_count < 2:
            transient_operation.retry_count += 1
            raise ConnectionError("Temporary network issue")
        return f"Success: {input_data}"
    
    transient_operation.retry_count = 0
    
    result, error = retry_node.execute_with_retry(transient_operation, "test_input")
    
    assert error is None, f"Expected success, got error: {error}"
    assert result == "Success: test_input"
    assert transient_operation.retry_count == 2

def test_permanent_error_handling():
    """Test handling of permanent errors"""
    # Test permanent error that should not be retried
    def permanent_operation(input_data):
        raise ValueError("Invalid input data")
    
    result, error = retry_node.execute_with_retry(permanent_operation, "invalid_input")
    
    assert result is None
    assert error is not None
    assert error["error_type"] == ErrorType.PERMANENT

def test_fallback_mechanism():
    """Test fallback mechanism"""
    # Configure fallback strategy
    fallback_node = FallbackNode()
    fallback_node.fallback_strategy.add_fallback(fallback_to_cache, priority=1)
    fallback_node.fallback_strategy.add_fallback(fallback_to_default, priority=2)
    
    # Test operation that fails and uses fallback
    def failing_operation(input_data):
        raise RuntimeError("Operation failed")
    
    result, error = fallback_node.execute_with_fallback(failing_operation, "test_input")
    
    assert error is None
    assert result == "default_cached_value" or result.startswith("default_value_for_")
    assert error.get("fallback_used") is True

def test_circuit_breaker():
    """Test circuit breaker functionality"""
    # Create circuit breaker with low threshold
    circuit_breaker_node = CircuitBreakerNode(failure_threshold=2, recovery_timeout=1.0)
    
    # Test operation that fails twice
    def failing_operation(input_data):
        raise ConnectionError("Service unavailable")
    
    # First failure
    result, error = circuit_breaker_node.execute_with_circuit_breaker(failing_operation, "test_input")
    assert result is None
    assert error is not None
    
    # Second failure should open circuit
    result, error = circuit_breaker_node.execute_with_circuit_breaker(failing_operation, "test_input")
    assert result is None
    assert error is not None
    assert error["error_details"]["circuit_state"] == "OPEN"

def test_adaptive_recovery():
    """Test adaptive recovery strategy"""
    # Register recovery strategies
    adaptive_recovery = AdaptiveRecovery()
    adaptive_recovery.register_strategy(ErrorType.TRANSIENT, transient_recovery)
    adaptive_recovery.register_strategy(ErrorType.PERMANENT, permanent_recovery)
    
    # Test transient error with adaptive recovery
    def transient_error_operation(input_data):
        raise ConnectionError("Temporary issue")
    
    result, error = adaptive_recovery.execute_with_adaptive_recovery(
        transient_error_operation,
        "test_input"
    )
    
    assert error is None or error.get("recovery_successful") is True
    assert result is not None

def test_multi_stage_recovery():
    """Test multi-stage recovery"""
    # Create multi-stage recovery
    multi_stage_recovery = MultiStageRecovery([
        {"name": "retry", "function": stage_1_retry},
        {"name": "fallback", "function": stage_2_fallback},
        {"name": "degradation", "function": stage_3_degradation}
    ])
    
    # Test operation that fails all recovery stages
    def failing_operation(input_data):
        raise RuntimeError("All recovery stages failed")
    
    result, error, recovery_successful = multi_stage_recovery.execute_recovery(
        {"error_type": ErrorType.UNRECOVERABLE},
        "test_input"
    )
    
    assert result is None
    assert error is not None
    assert error.get("all_recovery_stages_failed") is True
    assert recovery_successful is False
```

### 5.2 Integration Testing Error Flow

```python
def test_complete_error_flow():
    """Test complete error flow through graph"""
    # Create graph with error handling
    graph = StateGraph(SafeState)
    
    graph.add_node("operation", operation_node)
    graph.add_node("retry", retry_node)
    graph.add_node("fallback", fallback_node)
    graph.add_node("circuit_breaker", circuit_breaker_node)
    graph.add_node("recovery", recovery_node)
    graph.add_node("reporting", reporting_node)
    graph.add_node("monitoring", monitoring_node)
    
    # Set up error flow
    graph.set_entry_point("operation")
    
    # Conditional edges for error handling
    graph.add_conditional_edges(
        "operation",
        lambda state: state.get("error") is not None,
        {"continue": "retry", "error": "fallback"}
    )
    
    graph.add_conditional_edges(
        "retry",
        lambda state: state.get("error") is not None,
        {"continue": "circuit_breaker", "error": "recovery"}
    )
    
    graph.add_conditional_edges(
        "circuit_breaker",
        lambda state: state.get("error") is not None,
        {"continue": "fallback", "error": "recovery"}
    )
    
    graph.add_edge("fallback", "reporting")
    graph.add_edge("recovery", "reporting")
    graph.add_edge("reporting", "monitoring")
    graph.add_edge("monitoring", END)
    
    # Test with error-producing operation
    initial_state = {"input": "test_input"}
    
    # Configure operation to fail
    def failing_operation(input_data):
        raise ConnectionError("Test error")
    
    # Replace global operation with test version
    global perform_risky_operation
    perform_risky_operation = failing_operation
    
    # Execute graph
    result = graph.compile().invoke(initial_state)
    
    # Verify error handling flow
    assert result.get("error") is not None
    assert result.get("error").get("error_type") == ErrorType.TRANSIENT
    assert result.get("retry_count") > 0
    assert "fallback_used" in result.get("error", {})
    assert "recovery_successful" in result
    assert "error_logged" in result  # Assuming reporting node sets this
```

---

## Performance Considerations

### 6.1 Error Handling Overhead

```python
class PerformanceOptimizedErrorHandling:
    def __init__(self):
        self.error_cache = {}
        self.retry_counts = {}
    
    def fast_error_classification(self, error: Exception) -> ErrorContext:
        """Fast error classification using cache"""
        error_key = str(type(error))
        
        if error_key in self.error_cache:
            # Return cached classification
            return self.error_cache[error_key]
        
        # Classify error (could be more sophisticated)
        error_context = classify_error(error)
        
        # Cache classification
        self.error_cache[error_key] = error_context
        
        return error_context
    
    def optimized_retry(self, operation: Callable, *args, **kwargs) -> tuple[Any, Optional[ErrorContext]]:
        """Optimized retry with minimal overhead"""
        operation_key = f"{operation.__name__}_{args}_{kwargs}"
        
        # Check retry count from cache
        retry_count = self.retry_counts.get(operation_key, 0)
        
        try:
            result = operation(*args, **kwargs)
            # Reset retry count on success
            if operation_key in self.retry_counts:
                del self.retry_counts[operation_key]
            return result, None
            
        except Exception as e:
            error_context = self.fast_error_classification(e)
            
            # Update retry count
            self.retry_counts[operation_key] = retry_count + 1
            
            return None, error_context

# Usage in performance-critical node
def performance_node(state: SafeState) -> SafeState:
    """Performance-optimized error handling node"""
    optimized_handler = PerformanceOptimizedErrorHandling()
    
    result, error = optimized_handler.optimized_retry(
        perform_risky_operation,
        state["input"]
    )
    
    if error:
        return {
            "result": None,
            "error": error,
            "error_history": [],
            "retry_count": optimized_handler.retry_counts.get(f"perform_risky_operation_{state[\"input\"]}", 0)
        }
    
    return {
        "result": result,
        "error": None,
            "error_history": [],
            "retry_count": 0
        }
```

### 6.2 Error Handling in High-Throughput Systems

```python
class HighThroughputErrorHandling:
    def __init__(self, max_workers: int = 10):
        self.max_workers = max_workers
        self.executor = ThreadPoolExecutor(max_workers=max_workers)
        self.error_queue = Queue()
        self.results = {}
    
    def handle_errors_concurrently(self, operations: list) -> dict:
        """Handle multiple operations concurrently with error handling"""
        futures = []
        
        for operation in operations:
            future = self.executor.submit(self.execute_with_error_handling, operation)
            futures.append(future)
        
        # Collect results
        for future in as_completed(futures):
            operation_id, result, error = future.result()
            self.results[operation_id] = {"result": result, "error": error}
        
        return self.results
    
    def execute_with_error_handling(self, operation: tuple) -> tuple[str, Any, Optional[ErrorContext]]:
        """Execute single operation with error handling"""
        operation_id, operation_func, args, kwargs = operation
        
        try:
            result = operation_func(*args, **kwargs)
            return operation_id, result, None
            
        except Exception as e:
            error_context = classify_error(e)
            return operation_id, None, error_context

# Usage in batch processing node
def batch_processing_node(state: SafeState) -> SafeState:
    """Node for high-throughput batch processing with error handling"""
    operations = [
        (f"op_{i}", perform_risky_operation, (state["input"] + str(i),), {})
        for i in range(100)
    ]
    
    high_throughput_handler = HighThroughputErrorHandling(max_workers=20)
    results = high_throughput_handler.handle_errors_concurrently(operations)
    
    # Aggregate results
    successful_results = [r["result"] for r in results.values() if r["result"] is not None]
    errors = [r["error"] for r in results.values() if r["error"] is not None]
    
    return {
        "results": successful_results,
        "errors": errors,
        "error_count": len(errors),
        "success_count": len(successful_results)
    }
```

---

## Summary

This comprehensive guide covers:

| Topic | Key Points |
|-------|------------|
| **Core Concepts** | Error classification, basic handling patterns |
| **Advanced Patterns** | Retry strategies, circuit breakers, fallback mechanisms |
| **Recovery** | State recovery, rollback, adaptive recovery |
| **Production** | Monitoring, alerting, reporting, logging |
| **Testing** | Unit and integration testing for error scenarios |
| **Performance** | Optimized error handling for high-throughput systems |

---

*Document Version: 1.0*
*Last Updated: January 2026*

---

## Next Steps

After implementing error handling, explore:
- [Performance Optimization](../performance.md)
- [Security Considerations](../security.md)
- [Advanced Tool Usage](../tools.md)
- [Testing Strategies](../testing.md)