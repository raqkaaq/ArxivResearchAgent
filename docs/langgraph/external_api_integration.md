# External API Integration Guide for LangGraph

This guide covers best practices for integrating external APIs with LangGraph agents, including authentication, error handling, and data management patterns.

## Overview

LangGraph agents often need to interact with external services and APIs to retrieve data, perform actions, or integrate with third-party systems. This guide provides patterns and examples for building robust API integrations.

## Table of Contents

1. [API Integration Patterns](#api-integration-patterns)
2. [Authentication Strategies](#authentication-strategies)
3. [Error Handling and Retries](#error-handling-and-retries)
4. [Rate Limiting and Throttling](#rate-limiting-and-throttling)
5. [Data Transformation](#data-transformation)
6. [Caching Strategies](#caching-strategies)
7. [Testing API Integrations](#testing-api-integrations)
8. [Security Best Practices](#security-best-practices)
9. [Examples](#examples)

## API Integration Patterns

### Synchronous API Calls

For APIs that return immediate responses, use direct HTTP calls within your nodes:

```python
import httpx
from typing import TypedDict

class ApiState(TypedDict):
    api_response: dict | None
    error: str | None

async def api_call_node(state: ApiState):
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "https://api.example.com/data",
                headers={"Authorization": f"Bearer {state.get('api_key')}"}
            )
            response.raise_for_status()
            return {"api_response": response.json()}
    except httpx.HTTPStatusError as e:
        return {"error": f"API error: {e.response.status_code} - {e.response.text}"}
    except httpx.RequestError as e:
        return {"error": f"Network error: {str(e)}"}
```

### Asynchronous Background Processing

For long-running API operations, use background tasks and polling:

```python
import asyncio
import httpx
from typing import TypedDict

class BackgroundState(TypedDict):
    job_id: str | None
    status: str | None
    result: dict | None
    error: str | None

async def start_background_job(state: BackgroundState):
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.example.com/jobs",
            json={"task": "process_data"}
        )
        response.raise_for_status()
        job_data = response.json()
        return {"job_id": job_data["id"]}

async def poll_job_status(state: BackgroundState):
    if not state.get("job_id"):
        return {"error": "No job ID found"}
    
    async with httpx.AsyncClient() as client:
        while True:
            response = await client.get(
                f"https://api.example.com/jobs/{state['job_id']}"
            )
            response.raise_for_status()
            job_status = response.json()
            
            if job_status["status"] == "completed":
                return {"status": "completed", "result": job_status["result"]}
            elif job_status["status"] == "failed":
                return {"status": "failed", "error": job_status["error"]}
            
            await asyncio.sleep(5)  # Poll every 5 seconds
```

### Streaming API Integration

For APIs that support streaming responses:

```python
import httpx
from typing import TypedDict, Generator

class StreamingState(TypedDict):
    stream_data: list
    error: str | None

async def stream_api_node(state: StreamingState):
    try:
        async with httpx.AsyncClient() as client:
            async with client.stream("GET", "https://api.example.com/stream") as response:
                stream_data = []
                async for chunk in response.aiter_bytes():
                    # Process each chunk as it arrives
                    stream_data.append(chunk.decode())
                return {"stream_data": stream_data}
    except httpx.RequestError as e:
        return {"error": f"Streaming error: {str(e)}"}
```

## Authentication Strategies

### API Key Authentication

```python
from typing import TypedDict

class ApiKeyState(TypedDict):
    api_key: str | None
    headers: dict | None

async def set_api_headers(state: ApiKeyState):
    if not state.get("api_key"):
        return {"error": "API key not provided"}
    
    headers = {
        "Authorization": f"Bearer {state['api_key']}",
        "Content-Type": "application/json"
    }
    return {"headers": headers}
```

### OAuth 2.0 Integration

```python
import httpx
from typing import TypedDict

class OAuthState(TypedDict):
    access_token: str | None
    refresh_token: str | None
    token_expires_at: float | None

async def refresh_oauth_token(state: OAuthState):
    if not state.get("refresh_token"):
        return {"error": "No refresh token available"}
    
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://auth.example.com/token",
            data={
                "grant_type": "refresh_token",
                "refresh_token": state["refresh_token"],
                "client_id": "your_client_id",
                "client_secret": "your_client_secret"
            }
        )
        response.raise_for_status()
        token_data = response.json()
        
        return {
            "access_token": token_data["access_token"],
            "refresh_token": token_data.get("refresh_token"),
            "token_expires_at": time.time() + token_data["expires_in"]
        }
```

### JWT Token Management

```python
import jwt
import time
from typing import TypedDict

class JwtState(TypedDict):
    jwt_secret: str | None
    payload: dict | None
    token: str | None

async def generate_jwt_token(state: JwtState):
    if not state.get("jwt_secret") or not state.get("payload"):
        return {"error": "JWT secret and payload required"}
    
    token = jwt.encode(
        state["payload"],
        state["jwt_secret"],
        algorithm="HS256",
        headers={"exp": time.time() + 3600}  # 1 hour expiration
    )
    
    return {"token": token}
```

## Error Handling and Retries

### Retry with Exponential Backoff

```python
import asyncio
import httpx
from typing import TypedDict

class RetryState(TypedDict):
    max_retries: int
    base_delay: float
    current_retry: int

async def api_call_with_retry(state: RetryState, url: str, **kwargs):
    max_retries = state.get("max_retries", 3)
    base_delay = state.get("base_delay", 1.0)
    
    for attempt in range(max_retries):
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(url, **kwargs)
                response.raise_for_status()
                return {"response": response.json(), "error": None}
        except httpx.HTTPStatusError as e:
            if e.response.status_code in [429, 500, 502, 503, 504] and attempt < max_retries - 1:
                delay = base_delay * (2 ** attempt)
                await asyncio.sleep(delay)
                continue
            return {"response": None, "error": f"API error: {e.response.status_code} - {e.response.text}"}
        except httpx.RequestError as e:
            if attempt < max_retries - 1:
                delay = base_delay * (2 ** attempt)
                await asyncio.sleep(delay)
                continue
            return {"response": None, "error": f"Network error: {str(e)}"}
    
    return {"response": None, "error": "Max retries exceeded"}
```

### Circuit Breaker Pattern

```python
import time
from typing import TypedDict

class CircuitBreakerState(TypedDict):
    failure_count: int
    last_failure_time: float | None
    state: str  # "CLOSED", "OPEN", "HALF_OPEN"
    threshold: int
    timeout: float

async def circuit_breaker_api_call(state: CircuitBreakerState, api_function, *args, **kwargs):
    current_time = time.time()
    
    # Check if circuit is open
    if state.get("state") == "OPEN":
        if current_time - (state.get("last_failure_time", 0)) > state.get("timeout", 60):
            # Transition to HALF_OPEN after timeout
            state["state"] = "HALF_OPEN"
        else:
            return {"error": "Circuit breaker is OPEN"}
    
    try:
        result = await api_function(*args, **kwargs)
        # If successful, reset failure count and close circuit
        state["failure_count"] = 0
        state["state"] = "CLOSED"
        return result
    except Exception as e:
        state["failure_count"] = state.get("failure_count", 0) + 1
        state["last_failure_time"] = current_time
        
        # Open circuit if threshold is reached
        if state["failure_count"] >= state.get("threshold", 5):
            state["state"] = "OPEN"
        
        return {"error": f"API call failed: {str(e)}"}
```

## Rate Limiting and Throttling

### Token Bucket Algorithm

```python
import time
from typing import TypedDict

class TokenBucketState(TypedDict):
    capacity: int
    tokens: int
    refill_rate: float  # tokens per second
    last_refill_time: float

async def consume_tokens(state: TokenBucketState, tokens_needed: int = 1):
    current_time = time.time()
    
    # Refill tokens based on time elapsed
    time_elapsed = current_time - state.get("last_refill_time", current_time)
    tokens_to_add = time_elapsed * state.get("refill_rate", 1.0)
    state["tokens"] = min(
        state.get("capacity", 10),
        state.get("tokens", 0) + tokens_to_add
    )
    state["last_refill_time"] = current_time
    
    if state["tokens"] >= tokens_needed:
        state["tokens"] -= tokens_needed
        return {"allowed": True}
    else:
        return {"allowed": False, "wait_time": (tokens_needed - state["tokens"]) / state.get("refill_rate", 1.0)}
```

### Rate Limiter Node

```python
import asyncio
from typing import TypedDict

class RateLimitState(TypedDict):
    requests_per_minute: int
    window_start: float
    request_count: int

async def rate_limit_node(state: RateLimitState):
    current_time = time.time()
    window_duration = 60  # 1 minute
    
    # Reset window if needed
    if current_time - state.get("window_start", 0) > window_duration:
        state["window_start"] = current_time
        state["request_count"] = 0
    
    # Check if rate limit exceeded
    if state["request_count"] >= state.get("requests_per_minute", 60):
        time_until_next_window = window_duration - (current_time - state["window_start"])
        await asyncio.sleep(time_until_next_window)
        state["window_start"] = time.time()
        state["request_count"] = 0
    
    state["request_count"] += 1
    return {"rate_limited": False}
```

## Data Transformation

### Request/Response Transformation

```python
from typing import TypedDict, Any

class TransformState(TypedDict):
    input_data: dict | None
    transformed_data: dict | None
    error: str | None

async def transform_request(state: TransformState):
    try:
        input_data = state.get("input_data")
        if not input_data:
            return {"error": "No input data provided"}
        
        # Example transformation: convert to API-specific format
        transformed = {
            "api_version": "v2",
            "payload": {
                "query": input_data.get("query"),
                "filters": input_data.get("filters", {}),
                "options": {
                    "limit": input_data.get("limit", 10),
                    "offset": input_data.get("offset", 0)
                }
            }
        }
        
        return {"transformed_data": transformed}
    except Exception as e:
        return {"error": f"Transformation error: {str(e)}"}

async def transform_response(state: TransformState):
    try:
        api_response = state.get("api_response")
        if not api_response:
            return {"error": "No API response provided"}
        
        # Example transformation: convert API response to internal format
        transformed = {
            "results": [
                {
                    "id": item["id"],
                    "title": item["title"],
                    "score": item.get("relevance_score", 0),
                    "metadata": item.get("metadata", {})
                }
                for item in api_response.get("data", [])
            ],
            "total": api_response.get("total_count", 0),
            "query": api_response.get("query_used", "")
        }
        
        return {"transformed_data": transformed}
    except Exception as e:
        return {"error": f"Response transformation error: {str(e)}"}
```

## Caching Strategies

### In-Memory Caching

```python
import time
from typing import TypedDict, Any

class CacheState(TypedDict):
    cache: dict
    ttl: dict  # Time-to-live for each cache entry

async def get_from_cache(state: CacheState, key: str):
    cache = state.get("cache", {})
    ttl = state.get("ttl", {})
    
    if key in cache and key in ttl:
        if ttl[key] > time.time():
            return {"cached": True, "data": cache[key]}
        else:
            # Remove expired cache entry
            del cache[key]
            del ttl[key]
    
    return {"cached": False}

async def set_cache(state: CacheState, key: str, data: Any, ttl_seconds: int = 300):
    cache = state.get("cache", {})
    ttl = state.get("ttl", {})
    
    cache[key] = data
    ttl[key] = time.time() + ttl_seconds
    
    state["cache"] = cache
    state["ttl"] = ttl
    
    return {"cached": True}
```

### Distributed Caching with Redis

```python
import aioredis
from typing import TypedDict

class RedisCacheState(TypedDict):
    redis_client: aioredis.Redis | None
    cache_prefix: str

async def get_from_redis_cache(state: RedisCacheState, key: str):
    redis_client = state.get("redis_client")
    if not redis_client:
        return {"cached": False, "error": "Redis client not initialized"}
    
    cache_key = f"{state.get('cache_prefix', 'api_cache')}:{key}"
    
    try:
        cached_data = await redis_client.get(cache_key)
        if cached_data:
            return {"cached": True, "data": json.loads(cached_data)}
        return {"cached": False}
    except Exception as e:
        return {"cached": False, "error": f"Redis error: {str(e)}"}

async def set_redis_cache(state: RedisCacheState, key: str, data: dict, ttl_seconds: int = 300):
    redis_client = state.get("redis_client")
    if not redis_client:
        return {"cached": False, "error": "Redis client not initialized"}
    
    cache_key = f"{state.get('cache_prefix', 'api_cache')}:{key}"
    
    try:
        await redis_client.setex(
            cache_key,
            ttl_seconds,
            json.dumps(data)
        )
        return {"cached": True}
    except Exception as e:
        return {"cached": False, "error": f"Redis error: {str(e)}"}
```

## Testing API Integrations

### Unit Testing API Calls

```python
import pytest
import httpx
from unittest.mock import AsyncMock, patch
from typing import TypedDict

class TestApiState(TypedDict):
    mock_response: dict | None

@pytest.mark.asyncio
async def test_api_call():
    # Mock the API response
    mock_response = {"data": [{"id": 1, "name": "Test"}]}
    
    with patch('httpx.AsyncClient') as mock_client:
        mock_instance = mock_client.return_value.__aenter__.return_value
        mock_instance.get.return_value = AsyncMock(
            status_code=200,
            json=AsyncMock(return_value=mock_response)
        )
        
        # Call your API function
        result = await api_call_node(TestApiState(mock_response=mock_response))
        
        assert result["api_response"] == mock_response
        mock_instance.get.assert_called_once()

@pytest.mark.asyncio
async def test_api_error_handling():
    with patch('httpx.AsyncClient') as mock_client:
        mock_instance = mock_client.return_value.__aenter__.return_value
        mock_instance.get.side_effect = httpx.HTTPStatusError(
            response=httpx.Response(404)
        )
        
        result = await api_call_node(TestApiState())
        assert "error" in result
```

### Integration Testing

```python
import pytest
import httpx
from typing import TypedDict

class IntegrationTestState(TypedDict):
    api_key: str

@pytest.mark.asyncio
@pytest.mark.integration
async def test_real_api_integration():
    # Use a test API endpoint
    test_api_key = "your_test_api_key"
    
    state = IntegrationTestState(api_key=test_api_key)
    
    # Test the complete API integration flow
    result = await api_call_node(state)
    
    assert result["api_response"] is not None
    assert "data" in result["api_response"]
```

## Security Best Practices

### Input Validation

```python
import re
from typing import TypedDict

class ValidationState(TypedDict):
    input_data: dict | None
    errors: list

async def validate_api_input(state: ValidationState):
    errors = []
    input_data = state.get("input_data", {})
    
    # Validate required fields
    required_fields = ["query", "api_key"]
    for field in required_fields:
        if not input_data.get(field):
            errors.append(f"Missing required field: {field}")
    
    # Validate query length
    query = input_data.get("query", "")
    if len(query) > 1000:
        errors.append("Query exceeds maximum length of 1000 characters")
    
    # Validate API key format
    api_key = input_data.get("api_key", "")
    if not re.match(r'^[A-Za-z0-9]{32,64}$', api_key):
        errors.append("Invalid API key format")
    
    return {"errors": errors}
```

### Sensitive Data Handling

```python
import os
from typing import TypedDict

class SecurityState(TypedDict):
    api_key: str | None
    sensitive_data: dict | None

async def secure_api_integration(state: SecurityState):
    # Never log sensitive data
    sensitive_data = state.get("sensitive_data", {})
    
    # Mask sensitive information in logs
    masked_data = {
        k: ("***REDACTED***" if k.lower() in ["api_key", "password", "token"] else v)
        for k, v in sensitive_data.items()
    }
    
    # Use environment variables for secrets
    api_key = state.get("api_key") or os.getenv("API_KEY")
    if not api_key:
        return {"error": "API key not provided and not found in environment"}
    
    return {"api_key": api_key, "masked_data": masked_data}
```

### CORS and Security Headers

```python
from typing import TypedDict

class CorsState(TypedDict):
    allowed_origins: list
    headers: dict | None

async def set_security_headers(state: CorsState):
    headers = {
        "Content-Security-Policy": "default-src 'self'",
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        "Referrer-Policy": "strict-origin-when-cross-origin"
    }
    
    # Add CORS headers if needed
    if state.get("allowed_origins"):
        headers["Access-Control-Allow-Origin"] = ",".join(state["allowed_origins"])
        headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    
    return {"headers": headers}
```

## Examples

### Example 1: Complete API Integration Node

```python
import httpx
import asyncio
from typing import TypedDict

class CompleteApiState(TypedDict):
    api_url: str
    api_key: str
    query: str
    results: list | None
    error: str | None

async def complete_api_integration_node(state: CompleteApiState):
    # Validate input
    if not state.get("api_url") or not state.get("api_key") or not state.get("query"):
        return {"error": "Missing required parameters"}
    
    try:
        # Set up API client with authentication
        async with httpx.AsyncClient() as client:
            headers = {
                "Authorization": f"Bearer {state['api_key']}",
                "Content-Type": "application/json"
            }
            
            # Make API call
            response = await client.post(
                state["api_url"],
                json={"query": state["query"]},
                headers=headers
            )
            response.raise_for_status()
            
            # Process response
            api_data = response.json()
            results = [
                {
                    "id": item["id"],
                    "title": item["title"],
                    "score": item.get("relevance_score", 0),
                    "metadata": item.get("metadata", {})
                }
                for item in api_data.get("results", [])
            ]
            
            return {"results": results}
            
    except httpx.HTTPStatusError as e:
        return {"error": f"API error: {e.response.status_code} - {e.response.text}"}
    except httpx.RequestError as e:
        return {"error": f"Network error: {str(e)}"}
    except Exception as e:
        return {"error": f"Unexpected error: {str(e)}"}
```

### Example 2: Multi-API Workflow

```python
import asyncio
from typing import TypedDict

class MultiApiState(TypedDict):
    primary_api_response: dict | None
    secondary_api_response: dict | None
    combined_results: list | None
    error: str | None

async def multi_api_workflow(state: MultiApiState):
    # Step 1: Call primary API
    primary_result = await call_primary_api(state)
    if primary_result.get("error"):
        return {"error": f"Primary API failed: {primary_result['error']}"}
    
    state["primary_api_response"] = primary_result["response"]
    
    # Step 2: Call secondary API based on primary results
    if primary_result["response"].get("data"):
        secondary_result = await call_secondary_api(state)
        if secondary_result.get("error"):
            return {"error": f"Secondary API failed: {secondary_result['error']}"}
        
        state["secondary_api_response"] = secondary_result["response"]
    
    # Step 3: Combine results
    combined = await combine_api_results(state)
    if combined.get("error"):
        return {"error": f"Result combination failed: {combined['error']}"}
    
    return {"combined_results": combined["results"]}
```

### Example 3: API Error Recovery

```python
import time
from typing import TypedDict

class ErrorRecoveryState(TypedDict):
    max_retries: int
    retry_count: int
    error: str | None
    recovered: bool

async def api_error_recovery(state: ErrorRecoveryState):
    if state.get("retry_count", 0) >= state.get("max_retries", 3):
        return {"error": "Max retries exceeded", "recovered": False}
    
    # Implement exponential backoff
    delay = 2 ** state.get("retry_count", 0)
    await asyncio.sleep(delay)
    
    # Try alternative API endpoint or method
    try:
        # Attempt alternative approach
        alternative_result = await try_alternative_api()
        
        if alternative_result.get("success"):
            return {"recovered": True, "retry_count": state.get("retry_count", 0) + 1}
        else:
            return {"error": "Alternative API failed", "recovered": False, "retry_count": state.get("retry_count", 0) + 1}
            
    except Exception as e:
        return {"error": f"Recovery attempt failed: {str(e)}", "recovered": False, "retry_count": state.get("retry_count", 0) + 1}
```

## Best Practices Summary

1. **Always validate input** before making API calls
2. **Implement proper error handling** with retries and circuit breakers
3. **Use authentication securely** and never log sensitive data
4. **Implement rate limiting** to respect API quotas
5. **Cache responses** when appropriate to reduce API calls
6. **Transform data** to match your internal data structures
7. **Test thoroughly** with both unit and integration tests
8. **Monitor API performance** and failures
9. **Handle timeouts gracefully** and provide fallback options
10. **Document API integrations** clearly for maintenance

This guide provides a comprehensive foundation for building robust external API integrations with LangGraph agents. Adapt these patterns to your specific use case and API requirements.