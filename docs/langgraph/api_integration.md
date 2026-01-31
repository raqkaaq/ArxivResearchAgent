# External API Integration Patterns

This guide covers comprehensive patterns for integrating external APIs with LangGraph agents, including REST APIs, GraphQL, webhooks, and authentication strategies.

## Table of Contents
1. [REST API Integration Patterns](#rest-api-integration-patterns)
2. [GraphQL Integration Patterns](#graphql-integration-patterns)
3. [Webhook Integration Patterns](#webhook-integration-patterns)
4. [Authentication Strategies](#authentication-strategies)
5. [Error Handling and Resilience](#error-handling-and-resilience)
6. [Performance Optimization](#performance-optimization)
7. [Best Practices and Security](#best-practices-and-security)
8. [Monitoring and Observability](#monitoring-and-observability)

## REST API Integration Patterns

### Basic REST Client Integration

```python
from langgraph.graph import State
from langchain_core.messages import AIMessage
import requests
from typing import Dict, Any, Optional

class RestApiClient:
    def __init__(self, base_url: str, headers: Optional[Dict[str, str]] = None):
        self.base_url = base_url.rstrip('/')
        self.session = requests.Session()
        if headers:
            self.session.headers.update(headers)
    
    def get(self, endpoint: str, params: Optional[Dict] = None) -> Dict[str, Any]:
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        response = self.session.get(url, params=params)
        response.raise_for_status()
        return response.json()
    
    def post(self, endpoint: str, data: Dict[str, Any]) -> Dict[str, Any]:
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        response = self.session.post(url, json=data)
        response.raise_for_status()
        return response.json()
    
    def put(self, endpoint: str, data: Dict[str, Any]) -> Dict[str, Any]:
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        response = self.session.put(url, json=data)
        response.raise_for_status()
        return response.json()
    
    def delete(self, endpoint: str) -> bool:
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        response = self.session.delete(url)
        response.raise_for_status()
        return response.status_code == 204
```

### REST API Integration with LangGraph

```python
from langgraph.graph import State
from langchain_core.messages import AIMessage
import requests
from typing import Dict, Any, Optional

class ApiIntegrationNode:
    def __init__(self, api_client: RestApiClient):
        self.api_client = api_client
    
    def __call__(self, state: State) -> State:
        # Extract parameters from state
        endpoint = state.get("endpoint")
        method = state.get("method", "GET")
        params = state.get("params", {})
        data = state.get("data", {})
        
        try:
            if method == "GET":
                response = self.api_client.get(endpoint, params)
            elif method == "POST":
                response = self.api_client.post(endpoint, data)
            elif method == "PUT":
                response = self.api_client.put(endpoint, data)
            elif method == "DELETE":
                response = self.api_client.delete(endpoint)
            else:
                raise ValueError(f"Unsupported method: {method}")
            
            # Update state with API response
            state["api_response"] = response
            state["success"] = True
            
        except requests.RequestException as e:
            state["api_error"] = str(e)
            state["success"] = False
        
        return state
```

## GraphQL Integration Patterns

### GraphQL Client Integration

```python
import requests
import json
from typing import Dict, Any, Optional, List

class GraphQLClient:
    def __init__(self, endpoint: str, headers: Optional[Dict[str, str]] = None):
        self.endpoint = endpoint
        self.session = requests.Session()
        if headers:
            self.session.headers.update(headers)
        self.session.headers.update({"Content-Type": "application/json"})
    
    def execute(self, query: str, variables: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        payload = {"query": query}
        if variables:
            payload["variables"] = variables
        
        response = self.session.post(self.endpoint, json=payload)
        response.raise_for_status()
        
        result = response.json()
        if "errors" in result:
            raise Exception(f"GraphQL errors: {result['errors']}")
        
        return result["data"]
    
    def batch_execute(self, queries: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        responses = []
        for query in queries:
            try:
                data = self.execute(query["query"], query.get("variables"))
                responses.append({"success": True, "data": data})
            except Exception as e:
                responses.append({"success": False, "error": str(e)})
        
        return responses
```

### GraphQL Integration with LangGraph

```python
from langgraph.graph import State
import json
from typing import Dict, Any

class GraphQLIntegrationNode:
    def __init__(self, graphql_client: GraphQLClient):
        self.graphql_client = graphql_client
    
    def __call__(self, state: State) -> State:
        query = state.get("graphql_query")
        variables = state.get("graphql_variables", {})
        
        try:
            data = self.graphql_client.execute(query, variables)
            state["graphql_data"] = data
            state["success"] = True
        except Exception as e:
            state["graphql_error"] = str(e)
            state["success"] = False
        
        return state
```

## Webhook Integration Patterns

### Webhook Receiver Integration

```python
from fastapi import FastAPI, Request
from typing import Dict, Any
import uvicorn
import json
from langgraph.graph import State

app = FastAPI()

class WebhookHandler:
    def __init__(self):
        self.pending_events = []
    
    async def handle_webhook(self, request: Request) -> Dict[str, Any]:
        try:
            data = await request.json()
            self.pending_events.append(data)
            return {"status": "success", "received": True}
        except Exception as e:
            return {"status": "error", "message": str(e)}
    
    def get_pending_events(self) -> List[Dict[str, Any]]:
        events = self.pending_events.copy()
        self.pending_events.clear()
        return events

# FastAPI route
@app.post("/webhook")
asynchronous def webhook_endpoint(request: Request):
    handler = WebhookHandler()
    return await handler.handle_webhook(request)

# Start the webhook server
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### Webhook Integration with LangGraph

```python
from langgraph.graph import State
from typing import Dict, Any
import time

class WebhookIntegrationNode:
    def __init__(self, webhook_handler: WebhookHandler, timeout: int = 30):
        self.webhook_handler = webhook_handler
        self.timeout = timeout
    
    def __call__(self, state: State) -> State:
        event_type = state.get("expected_event_type")
        start_time = time.time()
        
        while time.time() - start_time < self.timeout:
            events = self.webhook_handler.get_pending_events()
            
            for event in events:
                if event.get("type") == event_type:
                    state["webhook_event"] = event
                    state["success"] = True
                    return state
            
            time.sleep(1)
        
        state["webhook_error"] = f"Timeout waiting for {event_type} event"
        state["success"] = False
        return state
```

## Authentication Strategies

### API Key Authentication

```python
from typing import Dict, Any, Optional

class ApiKeyAuth:
    def __init__(self, api_key: str, header_name: str = "Authorization"):
        self.api_key = api_key
        self.header_name = header_name
    
    def get_headers(self) -> Dict[str, str]:
        return {self.header_name: f"Bearer {self.api_key}"}
    
    def authenticate_client(self, client: Any) -> None:
        headers = self.get_headers()
        if hasattr(client, "session") and client.session:
            client.session.headers.update(headers)
        elif hasattr(client, "headers"):
            client.headers.update(headers)
        else:
            raise ValueError("Client does not support header authentication")
```

### OAuth 2.0 Integration

```python
import requests
from typing import Dict, Any, Optional
from datetime import datetime, timedelta

class OAuth2Client:
    def __init__(self, client_id: str, client_secret: str, token_url: str):
        self.client_id = client_id
        self.client_secret = client_secret
        self.token_url = token_url
        self.access_token = None
        self.expires_at = None
    
    def get_access_token(self) -> str:
        if not self.access_token or self.expires_at and datetime.now() > self.expires_at:
            self._refresh_token()
        return self.access_token
    
    def _refresh_token(self) -> None:
        response = requests.post(self.token_url, data={
            'grant_type': 'client_credentials',
            'client_id': self.client_id,
            'client_secret': self.client_secret
        })
        
        response.raise_for_status()
        token_data = response.json()
        
        self.access_token = token_data['access_token']
        expires_in = token_data.get('expires_in', 3600)
        self.expires_at = datetime.now() + timedelta(seconds=expires_in * 0.9)
    
    def get_auth_headers(self) -> Dict[str, str]:
        return {"Authorization": f"Bearer {self.get_access_token()}"}
```

### JWT Token Management

```python
import jwt
from datetime import datetime, timedelta
from typing import Dict, Any, Optional

class JwtTokenManager:
    def __init__(self, secret: str, algorithm: str = "HS256"):
        self.secret = secret
        self.algorithm = algorithm
    
    def create_token(self, payload: Dict[str, Any], expires_in: int = 3600) -> str:
        issued_at = datetime.utcnow()
        expire_at = issued_at + timedelta(seconds=expires_in)
        
        token_payload = {
            "iat": issued_at,
            "exp": expire_at,
            **payload
        }
        
        return jwt.encode(token_payload, self.secret, algorithm=self.algorithm)
    
    def verify_token(self, token: str) -> Dict[str, Any]:
        return jwt.decode(token, self.secret, algorithms=[self.algorithm])
    
    def get_auth_headers(self, token: str) -> Dict[str, str]:
        return {"Authorization": f"Bearer {token}"}
```

## Error Handling and Resilience

### Circuit Breaker Pattern

```python
import time
from typing import Callable, Dict, Any, Optional
from collections import deque

class CircuitBreaker:
    def __init__(self, failure_threshold: int = 5, recovery_timeout: int = 30):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.failure_count = 0
        self.last_failure_time = None
        self.state = "CLOSED"  # CLOSED, OPEN, HALF_OPEN
        self.failure_log = deque(maxlen=10)
    
    def call(self, func: Callable, *args, **kwargs) -> Any:
        if self.state == "OPEN":
            if time.time() - self.last_failure_time > self.recovery_timeout:
                self.state = "HALF_OPEN"
            else:
                raise Exception("Circuit breaker is OPEN")
        
        try:
            result = func(*args, **kwargs)
            self._on_success()
            return result
        except Exception as e:
            self._on_failure()
            raise
    
    def _on_success(self) -> None:
        self.failure_count = 0
        self.state = "CLOSED"
        self.failure_log.clear()
    
    def _on_failure(self) -> None:
        self.failure_count += 1
        self.last_failure_time = time.time()
        self.failure_log.append(time.time())
        
        if self.failure_count >= self.failure_threshold:
            self.state = "OPEN"
    
    def is_healthy(self) -> bool:
        return self.state == "CLOSED" or self.state == "HALF_OPEN"
```

### Retry Logic with Exponential Backoff

```python
import time
import random
from typing import Callable, Any

class ExponentialBackoffRetry:
    def __init__(self, max_retries: int = 3, base_delay: float = 1.0, max_delay: float = 30.0):
        self.max_retries = max_retries
        self.base_delay = base_delay
        self.max_delay = max_delay
    
    def call(self, func: Callable, *args, **kwargs) -> Any:
        last_exception = None
        
        for attempt in range(self.max_retries + 1):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                last_exception = e
                if attempt < self.max_retries:
                    delay = min(self.max_delay, self.base_delay * (2 ** attempt))
                    jitter = delay * 0.1 * random.random()
                    time.sleep(delay + jitter)
                else:
                    break
        
        raise last_exception
```

## Performance Optimization

### Connection Pooling

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from typing import Dict, Any

class ConnectionPoolManager:
    def __init__(self, base_url: str, max_connections: int = 10, max_retries: int = 3):
        self.base_url = base_url
        self.session = requests.Session()
        
        # Configure retry strategy
        retry_strategy = Retry(
            total=max_retries,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["HEAD", "GET", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
        )
        
        # Mount adapter with connection pooling
        adapter = HTTPAdapter(
            max_retries=retry_strategy,
            pool_connections=max_connections,
            pool_maxsize=max_connections,
            pool_block=True
        )
        
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
    
    def get_connection(self) -> requests.Session:
        return self.session
```

### Request Batching

```python
from typing import List, Dict, Any, Callable
import asyncio
import concurrent.futures

class RequestBatcher:
    def __init__(self, max_batch_size: int = 10, max_workers: int = 5):
        self.max_batch_size = max_batch_size
        self.max_workers = max_workers
    
    def batch_requests(self, request_funcs: List[Callable], *args, **kwargs) -> List[Any]:
        results = []
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = [executor.submit(func, *args, **kwargs) for func in request_funcs]
            
            for future in concurrent.futures.as_completed(futures):
                try:
                    result = future.result()
                    results.append({"success": True, "data": result})
                except Exception as e:
                    results.append({"success": False, "error": str(e)})
        
        return results
    
    async def async_batch_requests(self, coroutines: List[Callable]) -> List[Any]:
        results = []
        
        async with asyncio.TaskGroup() as tg:
            for coroutine in coroutines:
                tg.create_task(self._async_request(coroutine, results))
        
        return results
    
    async def _async_request(self, coroutine: Callable, results: List[Any]) -> None:
        try:
            result = await coroutine
            results.append({"success": True, "data": result})
        except Exception as e:
            results.append({"success": False, "error": str(e)})
```

## Best Practices and Security

### Security Best Practices

```python
import hashlib
import hmac
from typing import Dict, Any, Optional

class ApiSecurity:
    def __init__(self, secret_key: str):
        self.secret_key = secret_key.encode('utf-8')
    
    def generate_signature(self, data: Dict[str, Any], timestamp: Optional[int] = None) -> str:
        if timestamp is None:
            timestamp = int(time.time())
        
        # Create canonical string
        canonical_string = self._create_canonical_string(data, timestamp)
        
        # Generate HMAC signature
        signature = hmac.new(self.secret_key, canonical_string.encode('utf-8'), hashlib.sha256)
        return signature.hexdigest()
    
    def _create_canonical_string(self, data: Dict[str, Any], timestamp: int) -> str:
        # Sort keys and create string representation
        sorted_keys = sorted(data.keys())
        parts = [f"{key}={data[key]}&" for key in sorted_keys]
        parts.append(f"timestamp={timestamp}")
        return "".join(parts)
    
    def verify_signature(self, data: Dict[str, Any], signature: str, timestamp: int) -> bool:
        expected_signature = self.generate_signature(data, timestamp)
        return hmac.compare_digest(expected_signature, signature)
```

### Rate Limiting

```python
import time
from collections import deque
from typing import Dict, Any

class RateLimiter:
    def __init__(self, max_requests: int, window_size: int):
        self.max_requests = max_requests
        self.window_size = window_size
        self.request_log = deque()
    
    def is_allowed(self) -> bool:
        current_time = time.time()
        
        # Remove old requests outside the window
        while self.request_log and current_time - self.request_log[0] > self.window_size:
            self.request_log.popleft()
        
        if len(self.request_log) < self.max_requests:
            self.request_log.append(current_time)
            return True
        return False
    
    def get_remaining_requests(self) -> int:
        current_time = time.time()
        
        # Remove old requests outside the window
        while self.request_log and current_time - self.request_log[0] > self.window_size:
            self.request_log.popleft()
        
        return max(0, self.max_requests - len(self.request_log))
```

## Monitoring and Observability

### API Metrics Collection

```python
import time
from typing import Dict, Any
from prometheus_client import Counter, Histogram, Gauge

class ApiMetrics:
    def __init__(self):
        # Initialize Prometheus metrics
        self.api_requests_total = Counter(
            'api_requests_total', 'Total API requests', ['method', 'endpoint', 'status']
        )
        self.api_request_duration = Histogram(
            'api_request_duration_seconds', 'API request duration', ['method', 'endpoint']
        )
        self.api_active_requests = Gauge(
            'api_active_requests', 'Current active API requests'
        )
    
    def record_request(self, method: str, endpoint: str, status: str, duration: float) -> None:
        self.api_requests_total.labels(method, endpoint, status).inc()
        self.api_request_duration.labels(method, endpoint).observe(duration)
    
    def record_start(self, method: str, endpoint: str) -> None:
        self.api_active_requests.inc()
        self.start_time = time.time()
        self.current_method = method
        self.current_endpoint = endpoint
    
    def record_end(self, status: str) -> None:
        duration = time.time() - self.start_time
        self.record_request(self.current_method, self.current_endpoint, status, duration)
        self.api_active_requests.dec()
```

### Logging and Tracing

```python
import logging
import json
from typing import Dict, Any

class ApiLogger:
    def __init__(self, logger_name: str = "api_logger"):
        self.logger = logging.getLogger(logger_name)
        self.logger.setLevel(logging.INFO)
        
        # Create console handler
        ch = logging.StreamHandler()
        ch.setLevel(logging.INFO)
        
        # Create formatter
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        ch.setFormatter(formatter)
        
        # Add handler to logger
        if not self.logger.hasHandlers():
            self.logger.addHandler(ch)
    
    def log_request(self, method: str, endpoint: str, data: Dict[str, Any]) -> None:
        log_data = {
            "event": "api_request",
            "method": method,
            "endpoint": endpoint,
            "data": data
        }
        self.logger.info(json.dumps(log_data))
    
    def log_response(self, status_code: int, response_data: Dict[str, Any]) -> None:
        log_data = {
            "event": "api_response",
            "status_code": status_code,
            "response": response_data
        }
        self.logger.info(json.dumps(log_data))
    
    def log_error(self, error: Exception, context: Dict[str, Any]) -> None:
        log_data = {
            "event": "api_error",
            "error": str(error),
            "context": context
        }
        self.logger.error(json.dumps(log_data))
```

## Integration Examples

### Complete API Integration Node

```python
from langgraph.graph import State
from langchain_core.messages import AIMessage
import time
from typing import Dict, Any, Optional

class CompleteApiIntegrationNode:
    def __init__(self, api_client: RestApiClient, metrics: ApiMetrics, logger: ApiLogger):
        self.api_client = api_client
        self.metrics = metrics
        self.logger = logger
        self.rate_limiter = RateLimiter(max_requests=100, window_size=60)
        self.circuit_breaker = CircuitBreaker(failure_threshold=5, recovery_timeout=60)
    
    def __call__(self, state: State) -> State:
        endpoint = state.get("endpoint")
        method = state.get("method", "GET")
        params = state.get("params", {})
        data = state.get("data", {})
        
        # Check rate limiting
        if not self.rate_limiter.is_allowed():
            state["api_error"] = "Rate limit exceeded"
            state["success"] = False
            return state
        
        try:
            # Record start time and metrics
            self.metrics.record_start(method, endpoint)
            self.logger.log_request(method, endpoint, {"params": params, "data": data})
            
            # Make API call with circuit breaker
            response = self.circuit_breaker.call(
                self._make_api_call, method, endpoint, params, data
            )
            
            # Record successful response
            self.logger.log_response(200, response)
            self.metrics.record_end("success", time.time() - self.metrics.start_time)
            
            state["api_response"] = response
            state["success"] = True
            
        except Exception as e:
            # Record error
            self.logger.log_error(e, {"method": method, "endpoint": endpoint})
            self.metrics.record_end("error", time.time() - self.metrics.start_time)
            
            state["api_error"] = str(e)
            state["success"] = False
        
        return state
    
    def _make_api_call(self, method: str, endpoint: str, params: Dict, data: Dict) -> Dict:
        if method == "GET":
            return self.api_client.get(endpoint, params)
        elif method == "POST":
            return self.api_client.post(endpoint, data)
        elif method == "PUT":
            return self.api_client.put(endpoint, data)
        elif method == "DELETE":
            return self.api_client.delete(endpoint)
        else:
            raise ValueError(f"Unsupported method: {method}")
```

## Testing API Integration

```python
import pytest
from unittest.mock import Mock, patch
from typing import Dict, Any

class TestApiIntegration:
    @pytest.fixture
    def api_client(self):
        return Mock()
    
    @pytest.fixture
    def api_integration_node(self, api_client):
        return CompleteApiIntegrationNode(api_client, Mock(), Mock())
    
    def test_successful_get_request(self, api_integration_node, api_client):
        # Setup mock response
        api_client.get.return_value = {"data": "test"}
        
        # Create state
        state = State({
            "endpoint": "test/endpoint",
            "method": "GET"
        })
        
        # Execute node
        result = api_integration_node(state)
        
        # Assertions
        assert result["success"] is True
        assert result["api_response"] == {"data": "test"}
        api_client.get.assert_called_once_with("test/endpoint", params={})
    
    def test_failed_request(self, api_integration_node, api_client):
        # Setup mock exception
        api_client.get.side_effect = Exception("API error")
        
        # Create state
        state = State({
            "endpoint": "test/endpoint",
            "method": "GET"
        })
        
        # Execute node
        result = api_integration_node(state)
        
        # Assertions
        assert result["success"] is False
        assert "API error" in result["api_error"]
        api_client.get.assert_called_once_with("test/endpoint", params={})
    
    def test_rate_limiting(self, api_integration_node):
        # Setup rate limiter to block
        api_integration_node.rate_limiter.is_allowed = Mock(return_value=False)
        
        # Create state
        state = State({
            "endpoint": "test/endpoint",
            "method": "GET"
        })
        
        # Execute node
        result = api_integration_node(state)
        
        # Assertions
        assert result["success"] is False
        assert result["api_error"] == "Rate limit exceeded"
    
    def test_circuit_breaker_open(self, api_integration_node, api_client):
        # Setup circuit breaker to be open
        api_integration_node.circuit_breaker.state = "OPEN"
        api_integration_node.circuit_breaker.last_failure_time = time.time() - 30
        
        # Create state
        state = State({
            "endpoint": "test/endpoint",
            "method": "GET"
        })
        
        # Execute node
        with pytest.raises(Exception) as exc_info:
            api_integration_node(state)
        
        # Assertions
        assert str(exc_info.value) == "Circuit breaker is OPEN"
```
