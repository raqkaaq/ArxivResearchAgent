# Comprehensive Testing Guide for LangGraph Apps

This guide covers comprehensive testing strategies for LangGraph applications, including unit testing, integration testing, end-to-end testing, and performance testing patterns.

## Overview

Testing LangGraph applications requires a multi-faceted approach due to their stateful, graph-based nature. This guide covers testing at all levels: individual nodes, graph execution, state management, and integration with external systems.

## Testing Architecture

### 1. Testing Pyramid

```
        E2E Tests (5-10%)
       ├── Integration Tests (20-30%)
       └── Unit Tests (60-75%)
```

### 2. Testing Categories

| Category | Scope | Tools | Frequency |
|----------|-------|-------|-----------|
| Unit Tests | Individual nodes | pytest, unittest | Every change |
| Integration Tests | Node interactions | pytest, unittest | Feature changes |
| E2E Tests | Complete workflows | pytest, playwright | Release cycles |
| Performance Tests | Load and speed | pytest-benchmark, locust | Performance tuning |
| State Tests | State management | pytest | Architecture changes |
| Error Tests | Failure scenarios | pytest | Security reviews |

## Unit Testing

### 1. Testing Individual Nodes

Test each node in isolation to ensure correct behavior.

```python
import pytest
from typing import TypedDict, Any
from unittest.mock import Mock, patch

# Define test state structure
class TestState(TypedDict):
    query: str
    papers: list
    result: str | None
    error: str | None

# Test node functions
@pytest.mark.unit
def test_search_node_basic():
    """Test search node with valid input"""
    # Arrange
    state: TestState = {
        "query": "machine learning",
        "papers": [],
        "result": None,
        "error": None
    }
    
    # Act
    result_state = search_node(state)
    
    # Assert
    assert result_state["papers"] is not None
    assert len(result_state["papers"]) > 0
    assert result_state["error"] is None

@pytest.mark.unit
def test_search_node_empty_query():
    """Test search node with empty query"""
    # Arrange
    state: TestState = {
        "query": "",
        "papers": [],
        "result": None,
        "error": None
    }
    
    # Act
    result_state = search_node(state)
    
    # Assert
    assert result_state["papers"] == []
    assert result_state["error"] is not None
    assert "empty query" in result_state["error"].lower()

@pytest.mark.unit
def test_analyze_node_with_results():
    """Test analyze node with search results"""
    # Arrange
    state: TestState = {
        "query": "machine learning",
        "papers": [{"title": "ML Paper 1"}, {"title": "ML Paper 2"}],
        "result": None,
        "error": None
    }
    
    # Act
    result_state = analyze_node(state)
    
    # Assert
    assert result_state["result"] is not None
    assert len(result_state["result"]) > 0
    assert result_state["error"] is None

@pytest.mark.unit
def test_analyze_node_no_results():
    """Test analyze node with no results"""
    # Arrange
    state: TestState = {
        "query": "machine learning",
        "papers": [],
        "result": None,
        "error": None
    }
    
    # Act
    result_state = analyze_node(state)
    
    # Assert
    assert result_state["result"] is None
    assert result_state["error"] is not None
    assert "no papers" in result_state["error"].lower()
```

### 2. Testing with Mocks

Use mocking to isolate node behavior from external dependencies.

```python
@patch('langchain_openai.ChatOpenAI')
@patch('langchain_community.tools.ArxivAPI')
def test_search_node_with_mocks(mock_arxiv, mock_llm):
    """Test search node with mocked dependencies"""
    # Arrange
    mock_arxiv_instance = Mock()
    mock_arxiv.return_value = mock_arxiv_instance
    
    mock_arxiv_instance.run.return_value = [
        {"title": "Test Paper 1", "id": "1"},
        {"title": "Test Paper 2", "id": "2"}
    ]
    
    state: TestState = {
        "query": "test query",
        "papers": [],
        "result": None,
        "error": None
    }
    
    # Act
    result_state = search_node(state)
    
    # Assert
    mock_arxiv.assert_called_once()
    mock_arxiv_instance.run.assert_called_once_with("test query")
    assert len(result_state["papers"]) == 2
    assert result_state["papers"][0]["title"] == "Test Paper 1"
```

### 3. Parameterized Testing

Test nodes with multiple input combinations.

```python
import pytest
from typing import List, Dict, Any

@pytest.mark.parametrize("query, expected_count", [
    ("machine learning", 5),
    ("deep learning", 3),
    ("", 0),
    ("a", 0)
])
def test_search_node_parameterized(query: str, expected_count: int):
    """Test search node with parameterized inputs"""
    # Arrange
    state: TestState = {
        "query": query,
        "papers": [],
        "result": None,
        "error": None
    }
    
    # Act
    result_state = search_node(state)
    
    # Assert
    if expected_count > 0:
        assert len(result_state["papers"]) == expected_count
        assert result_state["error"] is None
    else:
        assert len(result_state["papers"]) == 0
        assert result_state["error"] is not None

@pytest.mark.parametrize("input_data, should_succeed", [
    ({"query": "valid query", "max_results": 5}, True),
    ({"query": "", "max_results": 5}, False),
    ({"query": "valid query", "max_results": 0}, False),
    ({"query": "valid query", "max_results": 101}, False)
])
def test_validated_search_parameterized(input_data: dict, should_succeed: bool):
    """Test validated search with parameterized inputs"""
    # Arrange
    state: TestState = {
        "query": input_data.get("query", ""),
        "papers": [],
        "result": None,
        "error": None
    }
    
    # Act
    result_state = validated_search(**input_data)
    
    # Assert
    if should_succeed:
        assert result_state["success"] == True
        assert result_state["error"] is None
    else:
        assert result_state["success"] == False
        assert result_state["error"] is not None
```

### 4. Testing Error Handling

Test how nodes handle various error conditions.

```python
@pytest.mark.unit
def test_node_error_handling():
    """Test node error handling patterns"""
    # Test transient error handling
    with patch('external_api.search', side_effect=ConnectionError("API unavailable")):
        state = {"query": "test", "papers": [], "error": None}
        result = resilient_search(state["query"])
        assert result["success"] == False
        assert "connection" in result["error"].lower()

@pytest.mark.unit
def test_validation_errors():
    """Test validation error handling"""
    # Test invalid input handling
    invalid_state = {"query": None, "papers": [], "error": None}
    
    with pytest.raises(ValueError, match="Query must be at least 3 characters"):
        validated_search(query="")
    
    with pytest.raises(ValueError, match="max_results must be between 1 and 100"):
        validated_search(query="valid", max_results=0)

@pytest.mark.unit
def test_retry_logic():
    """Test retry logic in error handling"""
    # Test retry mechanism
    with patch('external_api.search', side_effect=[ConnectionError(), ConnectionError(), "success"]):
        result = resilient_search("test", max_retries=3)
        assert result["success"] == True
        assert result["attempts"] == 3

@pytest.mark.unit
def test_fallback_behaviors():
    """Test fallback behavior when primary method fails"""
    # Test fallback to secondary method
    with patch('primary_method.search', side_effect=Exception("Primary failed")):
        with patch('fallback_method.search', return_value="fallback success"):
            result = search_with_fallback("test")
            assert result == "fallback success"
```

## Integration Testing

### 1. Testing Node Interactions

Test how nodes work together in sequence.

```python
@pytest.mark.integration
def test_node_sequence():
    """Test complete node sequence"""
    # Arrange
    initial_state: TestState = {
        "query": "machine learning",
        "papers": [],
        "result": None,
        "error": None
    }
    
    # Act - Execute node sequence
    state_after_search = search_node(initial_state)
    state_after_analysis = analyze_node(state_after_search)
    
    # Assert - Check intermediate states
    assert len(state_after_search["papers"]) > 0
    assert state_after_search["error"] is None
    
    assert state_after_analysis["result"] is not None
    assert state_after_analysis["error"] is None
    
    # Check state transitions
    assert state_after_search["query"] == initial_state["query"]
    assert state_after_analysis["query"] == initial_state["query"]

@pytest.mark.integration
def test_state_preservation_across_nodes():
    """Test state preservation across node boundaries"""
    # Arrange
    initial_state = {
        "query": "test query",
        "papers": [],
        "metadata": {"user_id": "test_user"},
        "error": None
    }
    
    # Act
    state_after_search = search_node(initial_state)
    state_after_analysis = analyze_node(state_after_search)
    
    # Assert - Check state preservation
    assert state_after_search["metadata"] == initial_state["metadata"]
    assert state_after_analysis["metadata"] == initial_state["metadata"]
    
    # Check that only expected fields are modified
    unchanged_fields = ["query", "metadata"]
    for field in unchanged_fields:
        assert state_after_analysis[field] == initial_state[field]
```

### 2. Testing Conditional Logic

Test conditional branching and routing logic.

```python
@pytest.mark.integration
def test_conditional_branching():
    """Test conditional branching logic"""
    # Test continue condition
    continue_state = {
        "messages": [AIMessage(content="I need to search for papers", tool_calls=["search"])]
    }
    assert should_continue_agent(continue_state) == "continue"
    
    # Test end condition
    end_state = {
        "messages": [AIMessage(content="Here are the results")]
    }
    assert should_continue_agent(end_state) == "end"

@pytest.mark.integration
def test_error_propagation():
    """Test error propagation through node chain"""
    # Arrange
    error_state = {
        "query": "test",
        "papers": [],
        "error": "Initial error"
    }
    
    # Act
    state_after_search = search_node(error_state)
    state_after_analysis = analyze_node(state_after_search)
    
    # Assert - Check error propagation
    assert state_after_search["error"] is not None
    assert state_after_analysis["error"] is not None
    assert state_after_analysis["error"] != error_state["error"]  # Should have new error

@pytest.mark.integration
def test_state_recovery():
    """Test state recovery after errors"""
    # Arrange - Create state with error
    error_state = {
        "query": "test",
        "papers": [],
        "error": "Search failed"
    }
    
    # Act - Attempt recovery
    recovered_state = recover_from_error(error_state)
    
    # Assert - Check recovery
    assert recovered_state["error"] is None
    assert "recovered" in recovered_state.get("recovery_info", "").lower()
```

### 3. Testing State Management

Test state initialization, updates, and persistence.

```python
@pytest.mark.integration
def test_state_initialization():
    """Test state initialization patterns"""
    # Test default initialization
    default_state = initialize_state("test data")
    assert default_state["raw_data"] == "test data"
    assert default_state["results"] is None
    assert default_state["step_count"] == 0
    
    # Test custom initialization
    custom_state = initialize_state("custom data", user_id="test_user")
    assert custom_state["raw_data"] == "custom data"
    assert custom_state.get("user_id") == "test_user"

@pytest.mark.integration
def test_state_updates():
    """Test state update patterns"""
    # Test basic updates
    initial_state = initialize_state("initial")
    updated_state = update_state_with_results(initial_state, ["result1", "result2"])
    
    assert updated_state["results"] == ["result1", "result2"]
    assert updated_state["step_count"] == 1
    assert updated_state["query_history"] == ["initial"]

@pytest.mark.integration
def test_state_validation():
    """Test state validation patterns"""
    # Test valid state
    valid_state = {
        "query": "test",
        "papers": [{"title": "Test"}],
        "error": None
    }
    assert validate_state(valid_state) == True
    
    # Test invalid state
    invalid_state = {
        "query": None,
        "papers": "not a list",
        "error": None
    }
    assert validate_state(invalid_state) == False

@pytest.mark.integration
def test_state_compression():
    """Test state compression and decompression"""
    # Arrange
    original_state = {
        "query": "test",
        "papers": [{"title": "Long paper title" * 100}],
        "metadata": {"large_data": "x" * 10000}
    }
    
    # Act
    compressed = compress_state(original_state)
    decompressed = decompress_state(compressed)
    
    # Assert
    assert compressed != json.dumps(original_state)  # Should be compressed
    assert decompressed == original_state  # Should be identical after decompression
```

## End-to-End Testing

### 1. Testing Complete Workflows

Test entire application workflows from start to finish.

```python
@pytest.mark.e2e
def test_complete_research_workflow():
    """Test complete research workflow"""
    # Arrange - Create test client
    client = create_test_client()
    
    # Act - Execute complete workflow
    response = client.post("/research", json={
        "query": "machine learning",
        "max_results": 5
    })
    
    # Assert - Check complete workflow
    assert response.status_code == 200
    data = response.json()
    
    assert "results" in data
    assert len(data["results"]) == 5
    assert "analysis" in data
    assert "execution_time" in data
    assert data["error"] is None

@pytest.mark.e2e
def test_error_handling_in_workflow():
    """Test error handling in complete workflow"""
    # Arrange - Create test client with mocked errors
    client = create_test_client()
    
    # Mock API errors
    with patch('external_api.search', side_effect=ConnectionError("API unavailable")):
        response = client.post("/research", json={
            "query": "test",
            "max_results": 5
        })
    
    # Assert - Check error handling
    assert response.status_code == 200
    data = response.json()
    
    assert "error" in data
    assert data["success"] == False
    assert "api unavailable" in data["error"].lower()
    assert "results" not in data

@pytest.mark.e2e
def test_state_persistence():
    """Test state persistence across requests"""
    # Arrange - Create test client
    client = create_test_client()
    
    # Act - First request
    response1 = client.post("/research", json={
        "query": "first query",
        "max_results": 3
    })
    
    # Act - Second request with same session
    response2 = client.post("/research", json={
        "query": "second query",
        "max_results": 3
    })
    
    # Assert - Check state persistence
    assert response1.status_code == 200
    assert response2.status_code == 200
    
    data1 = response1.json()
    data2 = response2.json()
    
    # Check that state was preserved
    assert "session_id" in data1
    assert "session_id" in data2
    assert data1["session_id"] == data2["session_id"]
    
    # Check that both results are present
    assert len(data1["results"]) == 3
    assert len(data2["results"]) == 3
```

### 2. Testing with Real Data

Test workflows with realistic data and scenarios.

```python
@pytest.mark.e2e
@pytest.mark.parametrize("test_case", [
    {"query": "machine learning", "expected_field": "results", "min_count": 3},
    {"query": "deep learning", "expected_field": "analysis", "min_length": 50},
    {"query": "artificial intelligence", "expected_field": "related_papers", "min_count": 2}
])
def test_real_data_scenarios(test_case):
    """Test workflows with real data scenarios"""
    # Arrange - Create test client
    client = create_test_client()
    
    # Act - Execute query
    response = client.post("/research", json={
        "query": test_case["query"],
        "max_results": 5
    })
    
    # Assert - Check real data expectations
    assert response.status_code == 200
    data = response.json()
    
    assert test_case["expected_field"] in data
    
    if "min_count" in test_case:
        assert len(data[test_case["expected_field"]]) >= test_case["min_count"]
    
    if "min_length" in test_case:
        content = data[test_case["expected_field"]]
        if isinstance(content, str):
            assert len(content) >= test_case["min_length"]
        elif isinstance(content, list) and content:
            assert len(content[0]) >= test_case["min_length"]

@pytest.mark.e2e
def test_user_interaction_flow():
    """Test complete user interaction flow"""
    # Arrange - Create test client
    client = create_test_client()
    
    # Act - User submits initial query
    response1 = client.post("/research", json={
        "query": "initial query",
        "action": "search"
    })
    
    # Act - User refines search
    session_id = response1.json()["session_id"]
    response2 = client.post(f"/research/{session_id}", json={
        "query": "refined query",
        "action": "refine"
    })
    
    # Act - User requests analysis
    response3 = client.post(f"/research/{session_id}", json={
        "action": "analyze"
    })
    
    # Assert - Check complete interaction
    assert response1.status_code == 200
    assert response2.status_code == 200
    assert response3.status_code == 200
    
    data1 = response1.json()
    data2 = response2.json()
    data3 = response3.json()
    
    assert "results" in data1
    assert "results" in data2
    assert "analysis" in data3
```

## Performance Testing

### 1. Load Testing

Test application performance under load.

```python
import time
import pytest
from typing import Dict, Any

@pytest.mark.performance
def test_node_performance():
    """Test individual node performance"""
    # Warm up
    for _ in range(3):
        search_node({"query": "warmup", "papers": [], "error": None})
    
    # Measure execution time
    start_time = time.time()
    for _ in range(10):
        search_node({"query": "performance test", "papers": [], "error": None})
    end_time = time.time()
    
    total_time = end_time - start_time
    avg_time = total_time / 10
    
    # Assert performance thresholds
    assert avg_time < 0.5, f"Node too slow: {avg_time:.3f}s"
    assert total_time < 5.0, f"Batch too slow: {total_time:.3f}s"

@pytest.mark.performance
def test_concurrent_execution():
    """Test concurrent node execution"""
    import asyncio
    from concurrent.futures import ThreadPoolExecutor
    
    async def execute_node_concurrently():
        """Execute nodes concurrently"""
        with ThreadPoolExecutor(max_workers=5) as executor:
            loop = asyncio.get_event_loop()
            
            # Create tasks
            tasks = []
            for i in range(10):
                task = loop.run_in_executor(
                    executor,
                    search_node,
                    {"query": f"concurrent test {i}", "papers": [], "error": None}
                )
                tasks.append(task)
            
            # Execute concurrently
            results = await asyncio.gather(*tasks)
            
            # Check all results
            for result in results:
                assert len(result["papers"]) > 0
                assert result["error"] is None
    
    # Measure concurrent execution
    start_time = time.time()
    asyncio.run(execute_node_concurrently())
    end_time = time.time()
    
    total_time = end_time - start_time
    assert total_time < 2.0, f"Concurrent execution too slow: {total_time:.3f}s"

@pytest.mark.performance
def test_memory_usage():
    """Test memory usage patterns"""
    import tracemalloc
    
    # Start tracking memory
    tracemalloc.start()
    
    # Create large state
    large_state = {
        "query": "memory test",
        "papers": [{"title": "Paper" + str(i)} for i in range(1000)],
        "metadata": {"key": "value" * 100},
        "error": None
    }
    
    # Execute operations
    for _ in range(10):
        search_node(large_state)
        analyze_node(large_state)
    
    # Measure memory
    current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    
    # Assert memory thresholds
    assert current < 50 * 1024 * 1024, f"Current memory too high: {current / 1024 / 1024:.2f}MB"
    assert peak < 100 * 1024 * 1024, f"Peak memory too high: {peak / 1024 / 1024:.2f}MB"
```

### 2. Stress Testing

Test application behavior under extreme conditions.

```python
@pytest.mark.stress
def test_extreme_input_sizes():
    """Test behavior with extreme input sizes"""
    # Test very large queries
    large_query = "x" * 100000
    state = {"query": large_query, "papers": [], "error": None}
    
    with pytest.raises(ValueError, match="Query too long"):
        validated_search(query=large_query)
    
    # Test maximum results
    with pytest.raises(ValueError, match="max_results must be between 1 and 100"):
        validated_search(query="valid", max_results=101)

@pytest.mark.stress
def test_concurrent_users():
    """Test behavior with many concurrent users"""
    import asyncio
    from typing import List
    
    async def simulate_user_behavior(user_id: int):
        """Simulate user behavior"""
        # User performs multiple actions
        for i in range(5):
            state = {
                "query": f"user_{user_id}_query_{i}",
                "papers": [],
                "error": None
            }
            
            # Execute search
            result = search_node(state)
            assert len(result["papers"]) >= 0
            
            # Add delay to simulate real usage
            await asyncio.sleep(0.1)
    
    # Simulate 50 concurrent users
    start_time = time.time()
    asyncio.run(asyncio.gather(*(simulate_user_behavior(i) for i in range(50))))
    end_time = time.time()
    
    total_time = end_time - start_time
    assert total_time < 10.0, f"Too slow with 50 users: {total_time:.3f}s"

@pytest.mark.stress
def test_error_recovery_under_load():
    """Test error recovery under load"""
    import random
    
    def flaky_search(state: dict) -> dict:
        """Search that randomly fails"""
        if random.random() < 0.3:  # 30% failure rate
            raise ConnectionError("Random failure")
        return search_node(state)
    
    # Test error recovery with high failure rate
    success_count = 0
    failure_count = 0
    
    for i in range(100):
        state = {"query": f"stress test {i}", "papers": [], "error": None}
        
        try:
            result = flaky_search(state)
            success_count += 1
        except ConnectionError:
            failure_count += 1
    
    # Assert reasonable success rate
    success_rate = success_count / 100
    assert success_rate > 0.5, f"Too many failures: {success_rate:.1%}"
```

## State Testing

### 1. State Validation Testing

Test state validation and integrity.

```python
@pytest.mark.state
def test_state_validation():
    """Test comprehensive state validation"""
    # Test valid state
    valid_state = {
        "query": "test",
        "papers": [{"title": "Test Paper"}],
        "result": "analysis result",
        "error": None,
        "step_count": 1,
        "execution_time": 0.5
    }
    assert validate_state(valid_state) == True
    
    # Test invalid state types
    invalid_type_state = {
        "query": 123,  # Should be string
        "papers": "not a list",  # Should be list
        "result": None,
        "error": None
    }
    assert validate_state(invalid_type_state) == False
    
    # Test missing required fields
    missing_field_state = {
        "papers": [{"title": "Test"}],
        "result": "analysis",
        "error": None
    }
    assert validate_state(missing_field_state) == False
    
    # Test state with errors
    error_state = {
        "query": "test",
        "papers": [],
        "result": None,
        "error": "Search failed",
        "step_count": 1
    }
    assert validate_state(error_state) == True  # Error state should still be valid

@pytest.mark.state
def test_state_transitions():
    """Test state transition logic"""
    # Test state progression
    initial_state = initialize_state("initial")
    assert initial_state["step_count"] == 0
    
    state_after_search = search_node(initial_state)
    assert state_after_search["step_count"] == 1
    
    state_after_analysis = analyze_node(state_after_search)
    assert state_after_analysis["step_count"] == 2
    
    # Test state rollback
    rolled_back_state = rollback_state(state_after_analysis, initial_state)
    assert rolled_back_state["step_count"] == 0
    assert rolled_back_state.get("rollback_count") == 1

@pytest.mark.state
def test_state_compression():
    """Test state compression and integrity"""
    # Create complex state
    complex_state = {
        "query": "complex test",
        "papers": [{"title": f"Paper {i}", "abstract": "x" * 1000} for i in range(100)],
        "metadata": {"user": "test", "preferences": {"theme": "dark"}},
        "history": [f"query_{i}" for i in range(50)],
        "error": None,
        "execution_time": 1.23
    }
    
    # Compress and decompress
    compressed = compress_state(complex_state)
    decompressed = decompress_state(compressed)
    
    # Verify integrity
    assert decompressed == complex_state
    assert len(compressed) < len(json.dumps(complex_state))  # Should be smaller
    
    # Test round-trip
    for _ in range(5):
        compressed = compress_state(complex_state)
        decompressed = decompress_state(compressed)
        assert decompressed == complex_state
```

### 2. State Persistence Testing

Test state persistence and recovery.

```python
@pytest.mark.state
def test_file_persistence():
    """Test file-based state persistence"""
    # Arrange - Create test state
    test_state = {
        "query": "test",
        "papers": [{"title": "Test Paper"}],
        "result": "analysis",
        "error": None,
        "step_count": 1
    }
    
    # Act - Save and load state
    save_state_to_file(test_state)
    loaded_state = load_state_from_file()
    
    # Assert - Check persistence
    assert loaded_state is not None
    assert loaded_state == test_state
    
    # Clean up
    if os.path.exists(PERSISTENCE_FILE):
        os.remove(PERSISTENCE_FILE)

@pytest.mark.state
def test_database_persistence():
    """Test database-based state persistence"""
    # Arrange - Create test database connection
    conn = create_test_database_connection()
    
    # Arrange - Create test state
    test_state = {
        "query": "database test",
        "papers": [{"title": "DB Paper"}],
        "result": "db analysis",
        "error": None,
        "step_count": 1
    }
    
    # Act - Save and load from database
    state_id = save_state_to_postgresql(test_state, conn)
    loaded_state = load_state_from_postgresql(state_id, conn)
    
    # Assert - Check database persistence
    assert loaded_state is not None
    assert loaded_state == test_state
    
    # Clean up
    with conn.cursor() as cursor:
        cursor.execute("DELETE FROM langgraph_states WHERE state_id = %s", (state_id,))
        conn.commit()

@pytest.mark.state
def test_state_recovery():
    """Test state recovery after failures"""
    # Arrange - Create state with error
    error_state = {
        "query": "test",
        "papers": [],
        "error": "Search failed",
        "step_count": 1
    }
    
    # Act - Recover state
    recovered_state = recover_state_from_error(error_state, Exception("Test error"))
    
    # Assert - Check recovery
    assert recovered_state["error"] == "Test error"
    assert recovered_state["error_count"] == 2
    assert "last_valid_state" in recovered_state
    assert recovered_state["last_valid_state"]["query"] == "test"
```

## Testing Utilities and Helpers

### 1. Test Fixtures

Create reusable test fixtures for common setup.

```python
import pytest
from typing import Generator

@pytest.fixture
def test_state():
    """Test state fixture"""
    return {
        "query": "test query",
        "papers": [],
        "result": None,
        "error": None,
        "step_count": 0
    }

@pytest.fixture
def mock_search_results():
    """Mock search results fixture"""
    return [
        {"title": "Test Paper 1", "id": "1", "abstract": "Abstract 1"},
        {"title": "Test Paper 2", "id": "2", "abstract": "Abstract 2"}
    ]

@pytest.fixture
def mock_llm():
    """Mock LLM fixture"""
    mock = Mock()
    mock.invoke.return_value = "Mock LLM response"
    return mock

@pytest.fixture
def test_client():
    """Test client fixture for E2E tests"""
    from fastapi.testclient import TestClient
    from main import app  # Your FastAPI app
    
    return TestClient(app)

@pytest.fixture
def test_database():
    """Test database fixture"""
    conn = create_test_database_connection()
    
    # Set up test data
    with conn.cursor() as cursor:
        cursor.execute("CREATE TEMP TABLE test_papers (id SERIAL, title TEXT)")
        cursor.executemany("INSERT INTO test_papers (title) VALUES (%s)", 
                          [(f"Test Paper {i}",) for i in range(5)])
        conn.commit()
    
    yield conn
    
    # Tear down
    with conn.cursor() as cursor:
        cursor.execute("DROP TABLE test_papers")
        conn.commit()
    conn.close()
```

### 2. Custom Test Assertions

Create custom assertions for LangGraph-specific testing.

```python
def assert_state_valid(state: dict, expected_fields: list = None):
    """Custom assertion for state validation"""
    assert isinstance(state, dict), "State must be a dictionary"
    
    if expected_fields:
        for field in expected_fields:
            assert field in state, f"State missing required field: {field}"
    
    # Check for None values in required fields
    required_fields = ["query", "papers", "error"]
    for field in required_fields:
        if field in state:
            assert state[field] is not None, f"Field {field} cannot be None"

def assert_node_execution_time(node_func, state, max_time: float = 0.5):
    """Custom assertion for node execution time"""
    import time
    
    start_time = time.time()
    node_func(state)
    execution_time = time.time() - start_time
    
    assert execution_time < max_time, f"Node execution too slow: {execution_time:.3f}s"

def assert_state_transition(initial_state, final_state, expected_changes):
    """Custom assertion for state transitions"""
    for field, expected_value in expected_changes.items():
        assert final_state.get(field) == expected_value, \
               f"Field {field} did not change as expected"
    
    # Check that other fields remained unchanged
    unchanged_fields = set(initial_state.keys()) - set(expected_changes.keys())
    for field in unchanged_fields:
        assert initial_state.get(field) == final_state.get(field), \
               f"Field {field} changed unexpectedly"
```

### 3. Test Data Generation

Generate realistic test data for comprehensive testing.

```python
def generate_test_paper_data(num_papers: int = 10) -> list:
    """Generate test paper data"""
    import random
    from faker import Faker
    
    fake = Faker()
    papers = []
    
    for i in range(num_papers):
        papers.append({
            "id": f"paper_{i}",
            "title": fake.sentence(nb_words=6),
            "abstract": fake.text(max_nb_chars=500),
            "authors": [fake.name() for _ in range(random.randint(1, 4))],
            "publication_date": fake.date_this_decade().isoformat(),
            "citations": random.randint(0, 100),
            "references": [f"ref_{j}" for j in range(random.randint(0, 10))]
        })
    
    return papers

def generate_test_user_queries(num_queries: int = 5) -> list:
    """Generate test user queries"""
    import random
    from faker import Faker
    
    fake = Faker()
    query_templates = [
        "machine learning for {}",
        "deep learning applications in {}",
        "{} research trends",
        "impact of {} on {}",
        "{} algorithms and techniques"
    ]
    
    topics = ["healthcare", "finance", "education", "climate change", "robotics"]
    
    queries = []
    for _ in range(num_queries):
        template = random.choice(query_templates)
        if "{}" in template:
            if template.count("{}") == 1:
                query = template.format(random.choice(topics))
            else:
                query = template.format(
                    random.choice(topics),
                    random.choice(topics)
                )
        else:
            query = template
        
        queries.append(query)
    
    return queries

def generate_test_state_with_history(num_steps: int = 5) -> dict:
    """Generate test state with execution history"""
    state = {
        "query": "test query",
        "papers": generate_test_paper_data(10),
        "result": "test result",
        "error": None,
        "step_count": num_steps,
        "execution_time": round(random.uniform(0.1, 2.0), 2),
        "query_history": generate_test_user_queries(num_steps),
        "processing_steps": [f"step_{i}" for i in range(num_steps)]
    }
    
    return state
```

## Test Configuration

### 1. pytest Configuration

Configure pytest for LangGraph testing.

```ini
# pytest.ini
[pytest]
minversion = 7.0
addopts = 
    --strict-markers
    --strict-config
    --cov=langgraph_app
    --cov-report=html
    --cov-report=term-missing
    --cov-fail-under=80
    --flake8
    --isort

markers =
    unit: Unit tests for individual nodes
    integration: Integration tests for node interactions
    e2e: End-to-end tests for complete workflows
    performance: Performance and load tests
    stress: Stress tests for extreme conditions
    state: State management and persistence tests

[coverage:run]
source = langgraph_app
source = tests
omit =
    */tests/*
    */__pycache__/*

[flake8]
max-line-length = 100
extend-ignore = E203, E501, W503
```

### 2. Test Environment Setup

Set up test environment variables and configurations.

```python
# conftest.py
import os
import pytest
from dotenv import load_dotenv

@pytest.fixture(scope="session", autouse=True)
def setup_test_environment():
    """Set up test environment"""
    # Load test environment variables
    load_dotenv(".env.test")
    
    # Set test-specific configurations
    os.environ["TESTING"] = "true"
    os.environ["DATABASE_URL"] = "postgresql://localhost:5432/test_db"
    os.environ["CACHE_ENABLED"] = "false"
    os.environ["LOG_LEVEL"] = "WARNING"
    
    # Create test directories
    os.makedirs("test_data", exist_ok=True)
    os.makedirs("test_results", exist_ok=True)

@pytest.fixture
def mock_external_services():
    """Mock external service responses"""
    # Mock external API responses
    with patch('external_api.search', return_value=generate_test_paper_data(5)):
        with patch('external_api.analyze', return_value="Mock analysis"):
            yield

@pytest.fixture
def performance_thresholds():
    """Performance thresholds fixture"""
    return {
        "node_execution": 0.5,      # seconds
        "batch_execution": 2.0,     # seconds
        "concurrent_users": 50,
        "memory_limit": 100 * 1024 * 1024  # bytes
    }
```

## Best Practices

### 1. Test Organization

- **Test Structure**: Organize tests by functionality and type
- **Naming Conventions**: Use descriptive test names that explain what is being tested
- **Test Independence**: Ensure tests can run in any order and don't depend on each other
- **Test Data Management**: Use fixtures and factories for consistent test data

### 2. Test Coverage

- **Unit Coverage**: Aim for 80%+ coverage on individual nodes
- **Integration Coverage**: Focus on critical interaction paths
- **E2E Coverage**: Test key user journeys and workflows
- **Edge Cases**: Test error conditions, boundary values, and failure scenarios

### 3. Test Maintenance

- **Test Documentation**: Document complex test scenarios and edge cases
- **Test Refactoring**: Regularly refactor tests to keep them maintainable
- **Test Data Management**: Use factories and fixtures to manage test data
- **Test Performance**: Monitor and optimize test execution time

### 4. Continuous Integration

- **Automated Testing**: Run tests automatically on code changes
- **Quality Gates**: Enforce test coverage and quality thresholds
- **Performance Monitoring**: Track performance regressions over time
- **Security Testing**: Include security-focused tests in CI/CD pipeline

## Conclusion

Comprehensive testing is essential for building reliable LangGraph applications. By following the patterns and best practices outlined in this guide, you can create a robust testing strategy that ensures your applications are correct, performant, and maintainable.

Remember to:
- Test at all levels: unit, integration, and end-to-end
- Include performance and stress testing
- Test state management and persistence thoroughly
- Use mocking and fixtures for isolated testing
- Monitor test coverage and quality metrics
- Maintain tests as your application evolves

The comprehensive testing approach outlined here will help you build confidence in your LangGraph applications and catch issues early in the development process.