# LangGraph Debugging Techniques and Tools

## Overview

This guide covers comprehensive debugging techniques for LangGraph applications, including debugging tools, visualization methods, state inspection, and troubleshooting common issues during graph execution.

---

## Core Debugging Concepts

### 1.1 Debugging Mindset

Debugging LangGraph applications requires understanding the flow of data through nodes, state transformations, and message passing patterns.

#### 1.1.1 Key Debugging Principles

```python
# Debugging Principles
class DebuggingPrinciples:
    def __init__(self):
        self.observe_everything = True  # Track all state changes
        self.isolate_problems = True   # Test individual nodes in isolation
        self.reproduce_issues = True   # Create minimal reproducible examples
        self.measure_performance = True # Monitor execution times
        self.validate_assumptions = True # Check assumptions about data flow
```

#### 1.1.2 Common Debugging Challenges

- State mutation and unexpected side effects
- Message passing issues between nodes
- Conditional logic failures in branching
- Performance bottlenecks in graph execution
- Integration issues with external services

---

## Built-in Debugging Tools

### 2.1 LangGraph Debug Mode

Enable debug mode to get detailed execution information.

```python
from langgraph.graph import StateGraph

# Enable debug mode
graph = StateGraph(State, debug=True)

# Configure debug output
graph.set_debug_options(
    verbose=True,
    log_level="DEBUG",
    show_state_transitions=True,
    show_message_passing=True
)
```

### 2.2 State Inspection Tools

#### 2.2.1 State Dumps

```python
class StateInspector:
    def __init__(self):
        self.checkpoint_states = []
        self.state_history = []
        self.state_transitions = []
    
    def dump_state(self, state: State, node_name: str, step: int) -> None:
        """Dump state for debugging"""
        state_copy = copy.deepcopy(state)
        
        # Remove sensitive data for logging
        if "sensitive_data" in state_copy:
            state_copy["sensitive_data"] = "[REDACTED]"
        
        # Log state
        print(f"=== State Dump at {node_name} (Step {step}) ===")
        print(json.dumps(state_copy, indent=2))
        print("=" * 50)
    
    def record_transition(self, from_state: State, to_state: State, node_name: str) -> None:
        """Record state transition"""
        transition = {
            "from_state": from_state,
            "to_state": to_state,
            "node": node_name,
            "timestamp": datetime.now().isoformat()
        }
        self.state_transitions.append(transition)
```

#### 2.2.2 State Comparison

```python
class StateComparator:
    @staticmethod
    def compare_states(state1: State, state2: State, ignore_keys: list = None) -> dict:
        """Compare two states and show differences"""
        ignore_keys = ignore_keys or []
        
        differences = {}
        
        for key in state1.keys():
            if key in ignore_keys:
                continue
                
            if key not in state2:
                differences[key] = {
                    "state1": state1[key],
                    "state2": None,
                    "change": "removed"
                }
            elif state1[key] != state2[key]:
                differences[key] = {
                    "state1": state1[key],
                    "state2": state2[key],
                    "change": "modified"
                }
        
        for key in state2.keys():
            if key not in state1 and key not in ignore_keys:
                differences[key] = {
                    "state1": None,
                    "state2": state2[key],
                    "change": "added"
                }
        
        return differences
```

### 2.3 Message Tracing

Track messages flowing through the graph.

```python
class MessageTracer:
    def __init__(self):
        self.message_log = []
        self.message_counts = {}
        self.message_types = {}
    
    def trace_message(self, message: Any, from_node: str, to_node: str) -> None:
        """Trace message passing"""
        message_id = uuid.uuid4().hex
        
        message_record = {
            "id": message_id,
            "message": message,
            "from_node": from_node,
            "to_node": to_node,
            "timestamp": datetime.now().isoformat(),
            "size": sys.getsizeof(message)
        }
        
        self.message_log.append(message_record)
        
        # Update statistics
        self.message_counts[to_node] = self.message_counts.get(to_node, 0) + 1
        message_type = type(message).__name__
        self.message_types[message_type] = self.message_types.get(message_type, 0) + 1
    
    def get_message_statistics(self) -> dict:
        """Get message statistics"""
        return {
            "total_messages": len(self.message_log),
            "messages_by_node": self.message_counts,
            "messages_by_type": self.message_types,
            "average_message_size": sum(m["size"] for m in self.message_log) / len(self.message_log) if self.message_log else 0
        }
```

---

## Visualization and Monitoring

### 3.1 Graph Visualization

Visualize the graph structure and execution flow.

#### 3.1.1 Graph Structure Visualization

```python
import networkx as nx
import matplotlib.pyplot as plt
from langgraph.graph import StateGraph

class GraphVisualizer:
    def __init__(self, graph: StateGraph):
        self.graph = graph
        self.nx_graph = nx.DiGraph()
    
    def build_visualization_graph(self) -> None:
        """Build NetworkX graph from LangGraph"""
        # Add nodes
        for node_name in self.graph.nodes:
            self.nx_graph.add_node(node_name)
        
        # Add edges
        for from_node, edges in self.graph.edges.items():
            for edge in edges:
                self.nx_graph.add_edge(from_node, edge)
    
    def visualize_graph(self, filename: str = "graph_visualization.png") -> None:
        """Visualize graph structure"""
        self.build_visualization_graph()
        
        plt.figure(figsize=(12, 8))
        pos = nx.spring_layout(self.nx_graph)
        
        # Draw nodes
        nx.draw_networkx_nodes(self.nx_graph, pos, node_size=700, node_color="lightblue")
        
        # Draw edges
        nx.draw_networkx_edges(self.nx_graph, pos, edgelist=self.nx_graph.edges(), edge_color="gray")
        
        # Draw labels
        nx.draw_networkx_labels(self.nx_graph, pos, font_size=12, font_weight="bold")
        
        plt.title("LangGraph Structure Visualization")
        plt.axis("off")
        plt.savefig(filename)
        plt.close()
        
        print(f"Graph visualization saved to {filename}")
```

#### 3.1.2 Execution Flow Visualization

```python
class ExecutionVisualizer:
    def __init__(self):
        self.execution_path = []
        self.node_execution_times = {}
        self.branch_execution = {}
    
    def record_execution(self, node_name: str, start_time: float, end_time: float) -> None:
        """Record node execution"""
        execution_time = end_time - start_time
        
        self.execution_path.append({
            "node": node_name,
            "start": start_time,
            "end": end_time,
            "duration": execution_time
        })
        
        # Update execution times
        if node_name not in self.node_execution_times:
            self.node_execution_times[node_name] = []
        self.node_execution_times[node_name].append(execution_time)
    
    def visualize_execution_flow(self, filename: str = "execution_flow.png") -> None:
        """Visualize execution flow"""
        if not self.execution_path:
            print("No execution data to visualize")
            return
        
        plt.figure(figsize=(12, 6))
        
        # Create Gantt chart
        y_positions = range(len(self.execution_path))
        durations = [exec["duration"] for exec in self.execution_path]
        labels = [exec["node"] for exec in self.execution_path]
        
        plt.barh(y_positions, durations, color="skyblue")
        plt.yticks(y_positions, labels)
        plt.xlabel("Time (seconds)")
        plt.title("Execution Flow Visualization")
        plt.grid(axis="x", alpha=0.3)
        
        plt.savefig(filename)
        plt.close()
        
        print(f"Execution flow visualization saved to {filename}")
```

### 3.2 Performance Monitoring

Monitor performance metrics during execution.

```python
class PerformanceMonitor:
    def __init__(self):
        self.metrics = {
            "execution_times": {},
            "memory_usage": {},
            "message_counts": {},
            "error_counts": {}
        }
        self.start_time = time.time()
    
    def record_execution_time(self, node_name: str, duration: float) -> None:
        """Record execution time"""
        if node_name not in self.metrics["execution_times"]:
            self.metrics["execution_times"][node_name] = []
        self.metrics["execution_times"][node_name].append(duration)
    
    def record_memory_usage(self, node_name: str, memory_mb: float) -> None:
        """Record memory usage"""
        if node_name not in self.metrics["memory_usage"]:
            self.metrics["memory_usage"][node_name] = []
        self.metrics["memory_usage"][node_name].append(memory_mb)
    
    def record_message_count(self, node_name: str, count: int) -> None:
        """Record message count"""
        self.metrics["message_counts"][node_name] = self.metrics["message_counts"].get(node_name, 0) + count
    
    def record_error(self, node_name: str) -> None:
        """Record error"""
        self.metrics["error_counts"][node_name] = self.metrics["error_counts"].get(node_name, 0) + 1
    
    def get_performance_summary(self) -> dict:
        """Get performance summary"""
        total_time = time.time() - self.start_time
        
        summary = {
            "total_execution_time": total_time,
            "total_memory_usage": sum(sum(usages) for usages in self.metrics["memory_usage"].values()),
            "total_messages": sum(self.metrics["message_counts"].values()),
            "total_errors": sum(self.metrics["error_counts"].values()),
            "node_statistics": {}
        }
        
        for node, times in self.metrics["execution_times"].items():
            summary["node_statistics"][node] = {
                "average_time": sum(times) / len(times),
                "total_time": sum(times),
                "execution_count": len(times),
                "memory_usage": sum(self.metrics["memory_usage"].get(node, [])) / len(self.metrics["memory_usage"].get(node, [1])) if self.metrics["memory_usage"].get(node) else 0,
                "message_count": self.metrics["message_counts"].get(node, 0),
                "error_count": self.metrics["error_counts"].get(node, 0)
            }
        
        return summary
```

---

## Debugging Techniques

### 4.1 Node-Level Debugging

Debug individual nodes in isolation.

#### 4.1.1 Unit Testing Nodes

```python
def test_node_in_isolation():
    """Test node in isolation"""
    # Create test state
    test_state = {
        "input": "test_input",
        "context": "test_context",
        "metadata": {}
    }
    
    # Test node function
    result = test_node(test_state)
    
    # Assert expected behavior
    assert result is not None, "Node should return result"
    assert "output" in result, "Node should produce output"
    assert result["output"] == expected_output, f"Expected {expected_output}, got {result["output"]}"
```

#### 4.1.2 Mock External Dependencies

```python
from unittest.mock import patch, MagicMock

def debug_node_with_mocks():
    """Debug node with mocked dependencies"""
    with patch('module.external_service') as mock_service:
        # Configure mock behavior
        mock_service.return_value = MagicMock(
            call_external_api=MagicMock(return_value={"success": True, "data": "mocked_data"})
        )
        
        # Test node
        test_state = {"input": "test_input"}
        result = node_with_external_dependency(test_state)
        
        # Verify behavior
        mock_service.call_external_api.assert_called_once()
        assert result["success"] is True
```

### 4.2 Graph-Level Debugging

Debug the entire graph execution.

#### 4.2.1 Step-by-Step Execution

```python
class StepByStepDebugger:
    def __init__(self, graph: StateGraph):
        self.graph = graph
        self.breakpoints = set()
        self.paused = False
        self.current_state = None
    
    def add_breakpoint(self, node_name: str) -> None:
        """Add breakpoint at node"""
        self.breakpoints.add(node_name)
    
    def remove_breakpoint(self, node_name: str) -> None:
        """Remove breakpoint"""
        self.breakpoints.discard(node_name)
    
    def step_through(self, initial_state: State) -> State:
        """Step through graph execution"""
        self.current_state = initial_state
        self.paused = False
        
        while True:
            # Get current node
            current_node = self.get_current_node(self.current_state)
            
            if current_node in self.breakpoints:
                self.paused = True
                print(f"Breakpoint hit at {current_node}")
                self.inspect_state()
                
                # Wait for user input
                user_input = input("Continue? (y/n/step/exit): ")
                if user_input.lower() == "n":
                    break
                elif user_input.lower() == "step":
                    self.paused = False
                elif user_input.lower() == "exit":
                    return self.current_state
            
            # Execute node
            try:
                self.current_state = self.graph.compile().invoke(self.current_state)
            except Exception as e:
                print(f"Error in {current_node}: {e}")
                break
        
        return self.current_state
    
    def inspect_state(self) -> None:
        """Inspect current state"""
        print("Current State:")
        print(json.dumps(self.current_state, indent=2))
```

#### 4.2.2 Conditional Breakpoints

```python
class ConditionalBreakpointDebugger:
    def __init__(self, graph: StateGraph):
        self.graph = graph
        self.conditionals = []
    
    def add_conditional_breakpoint(self, condition: Callable[[State], bool], description: str = "") -> None:
        """Add conditional breakpoint"""
        self.conditionals.append({
            "condition": condition,
            "description": description
        })
    
    def debug_with_conditions(self, initial_state: State) -> State:
        """Debug with conditional breakpoints"""
        current_state = initial_state
        
        while True:
            # Check conditions
            for conditional in self.conditionals:
                if conditional["condition"](current_state):
                    print(f"Conditional breakpoint triggered: {conditional["description"]}")
                    self.inspect_state(current_state)
                    
                    # Wait for user input
                    user_input = input("Continue? (y/n): ")
                    if user_input.lower() != "y":
                        return current_state
            
            # Execute next node
            try:
                current_state = self.graph.compile().invoke(current_state)
            except Exception as e:
                print(f"Error: {e}")
                break
        
        return current_state
```

### 4.3 State Debugging

Debug state transformations and mutations.

#### 4.3.1 State Mutation Tracking

```python
class StateMutationTracker:
    def __init__(self):
        self.mutation_log = []
        self.state_snapshots = []
    
    def track_mutation(self, old_state: State, new_state: State, node_name: str) -> None:
        """Track state mutation"""
        mutation = {
            "timestamp": datetime.now().isoformat(),
            "node": node_name,
            "changes": self.calculate_changes(old_state, new_state),
            "old_state_hash": self.hash_state(old_state),
            "new_state_hash": self.hash_state(new_state)
        }
        
        self.mutation_log.append(mutation)
        self.state_snapshots.append(new_state)
    
    def calculate_changes(self, old_state: State, new_state: State) -> dict:
        """Calculate state changes"""
        changes = {}
        
        # Track added keys
        for key in new_state.keys():
            if key not in old_state:
                changes[key] = {"action": "add", "old": None, "new": new_state[key]}
        
        # Track modified keys
        for key in old_state.keys():
            if key in new_state:
                if old_state[key] != new_state[key]:
                    changes[key] = {"action": "modify", "old": old_state[key], "new": new_state[key]}
            else:
                changes[key] = {"action": "remove", "old": old_state[key], "new": None}
        
        return changes
    
    def hash_state(self, state: State) -> str:
        """Create hash of state for comparison"""
        state_str = json.dumps(state, sort_keys=True)
        return hashlib.sha256(state_str.encode()).hexdigest()
```

#### 4.3.2 State Validation

```python
class StateValidator:
    def __init__(self, schema: dict):
        self.schema = schema
    
    def validate_state(self, state: State, node_name: str) -> bool:
        """Validate state against schema"""
        try:
            # Validate required fields
            for field, field_type in self.schema.items():
                if field not in state:
                    print(f"Validation error in {node_name}: Missing required field '{field}'")
                    return False
                
                if not isinstance(state[field], field_type):
                    print(f"Validation error in {node_name}: Field '{field}' should be {field_type.__name__}, got {type(state[field]).__name__}")
                    return False
            
            return True
            
        except Exception as e:
            print(f"Validation error in {node_name}: {e}")
            return False
```

---

## Common Debugging Scenarios

### 5.1 Node Not Executing

#### 5.1.1 Check Entry Point

```python
def debug_node_not_executing(graph: StateGraph, node_name: str) -> None:
    """Debug node that's not executing"""
    print(f"Debugging node: {node_name}")
    
    # Check if node exists
    if node_name not in graph.nodes:
        print(f"Error: Node '{node_name}' does not exist in graph")
        return
    
    # Check entry point
    entry_point = graph.entry_point
    if entry_point != node_name:
        print(f"Entry point is '{entry_point}', not '{node_name}'")
        print("Set entry point with graph.set_entry_point('{node_name}')")
    
    # Check edges
    edges_from = graph.edges.get(node_name, [])
    if not edges_from:
        print(f"Node '{node_name}' has no outgoing edges")
    
    edges_to = [from_node for from_node, to_nodes in graph.edges.items() if node_name in to_nodes]
    if not edges_to:
        print(f"Node '{node_name}' has no incoming edges")
```

#### 5.1.2 Check Conditional Logic

```python
def debug_conditional_logic(graph: StateGraph, node_name: str) -> None:
    """Debug conditional logic"""
    # Check conditional edges
    for from_node, edges in graph.edges.items():
        for edge in edges:
            if edge[0] == node_name:
                # Check if conditional
                if len(edge) > 2 and edge[2]:
                    print(f"Conditional edge to '{node_name}' from '{from_node}':")
                    print(f"Condition: {edge[2]}")
                    
                    # Test condition
                    test_state = {"input": "test_value"}  # Create test state
                    condition_result = edge[2](test_state)
                    print(f"Test condition result: {condition_result}")
```

### 5.2 State Not Updating

#### 5.2.1 Check State Mutation

```python
def debug_state_not_updating(node_function: Callable, input_state: State) -> None:
    """Debug state that's not updating"""
    print("Debugging state mutation:")
    
    # Get old state hash
    old_state_hash = hash_state(input_state)
    
    # Execute node
    try:
        output_state = node_function(input_state)
    except Exception as e:
        print(f"Node raised exception: {e}")
        return
    
    # Check if state changed
    new_state_hash = hash_state(output_state)
    if old_state_hash == new_state_hash:
        print("Warning: State did not change after node execution")
        print("Check if node is returning modified state")
    else:
        print("State changed successfully")
```

#### 5.2.2 Check Return Values

```python
def debug_return_values(node_function: Callable, input_state: State) -> None:
    """Debug return values"""
    # Execute node and capture return
    try:
        result = node_function(input_state)
        print("Node returned:")
        print(json.dumps(result, indent=2))
        
        # Check if result is valid state
        if not isinstance(result, dict):
            print("Warning: Node should return dictionary state")
        
    except Exception as e:
        print(f"Node raised exception: {e}")
```

### 5.3 Performance Issues

#### 5.3.1 Identify Bottlenecks

```python
def debug_performance_bottlenecks(graph: StateGraph, initial_state: State) -> None:
    """Debug performance bottlenecks"""
    performance_monitor = PerformanceMonitor()
    
    # Execute graph with timing
    start_time = time.time()
    
    try:
        result = graph.compile().invoke(initial_state)
    except Exception as e:
        print(f"Graph execution failed: {e}")
        return
    
    end_time = time.time()
    total_time = end_time - start_time
    
    print(f"Graph execution completed in {total_time:.2f} seconds")
    
    # Analyze performance
    performance_summary = performance_monitor.get_performance_summary()
    
    # Find slowest nodes
    slowest_nodes = sorted(
        performance_summary["node_statistics"].items(),
        key=lambda x: x[1]["average_time"],
        reverse=True
    )
    
    print("\nSlowest nodes:")
    for node, stats in slowest_nodes[:3]:
        print(f"{node}: {stats['average_time']:.3f}s (executed {stats['execution_count']} times)")
```

#### 5.3.2 Memory Usage

```python
def debug_memory_usage(graph: StateGraph, initial_state: State) -> None:
    """Debug memory usage"""
    import tracemalloc
    
    tracemalloc.start()
    
    # Execute graph
    try:
        result = graph.compile().invoke(initial_state)
    finally:
        current, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        
        print(f"Current memory usage: {current / 10**6:.2f}MB")
        print(f"Peak memory usage: {peak / 10**6:.2f}MB")
```

---

## Advanced Debugging Techniques

### 6.1 Custom Debug Nodes

Create custom nodes for debugging purposes.

```python
class DebugNode:
    def __init__(self, debug_message: str = "Debug node executed"):
        self.debug_message = debug_message
    
    def __call__(self, state: State) -> State:
        """Debug node that logs state and continues"""
        print(f"=== DEBUG NODE: {self.debug_message} ===")
        print(f"State at {datetime.now().isoformat()}:")
        print(json.dumps(state, indent=2))
        print("=" * 50)
        
        # Return state unchanged
        return state

# Usage in graph
def add_debug_nodes(graph: StateGraph) -> None:
    """Add debug nodes to graph"""
    # Add debug node between existing nodes
    graph.add_node("debug_before_operation", DebugNode("Before operation"))
    graph.add_node("debug_after_operation", DebugNode("After operation"))
    
    # Insert debug nodes into existing flow
    # This requires modifying the graph structure
    # For simplicity, assume we know the flow
    graph.add_edge("some_node", "debug_before_operation")
    graph.add_edge("debug_before_operation", "operation_node")
    graph.add_edge("operation_node", "debug_after_operation")
    graph.add_edge("debug_after_operation", "next_node")
```

### 6.2 Remote Debugging

Debug LangGraph applications running in remote environments.

```python
import socket
import json
from typing import Callable, Optional

class RemoteDebugger:
    def __init__(self, host: str = "localhost", port: int = 9999):
        self.host = host
        self.port = port
        self.server_socket = None
        self.client_socket = None
        self.connected = False
    
    def start_server(self) -> None:
        """Start remote debugging server"""
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.bind((self.host, self.port))
        self.server_socket.listen(1)
        
        print(f"Remote debugger listening on {self.host}:{self.port}")
        
        # Accept connection
        self.client_socket, addr = self.server_socket.accept()
        print(f"Debugger client connected from {addr}")
        self.connected = True
    
    def send_state(self, state: State, node_name: str) -> None:
        """Send state to remote debugger"""
        if not self.connected:
            return
        
        message = {
            "type": "state_update",
            "node": node_name,
            "state": state,
            "timestamp": datetime.now().isoformat()
        }
        
        try:
            self.client_socket.sendall(json.dumps(message).encode())
        except Exception as e:
            print(f"Error sending state: {e}")
            self.connected = False
    
    def receive_command(self) -> Optional[dict]:
        """Receive command from remote debugger"""
        if not self.connected:
            return None
        
        try:
            data = self.client_socket.recv(4096)
            if not data:
                self.connected = False
                return None
            
            return json.loads(data.decode())
        except Exception as e:
            print(f"Error receiving command: {e}")
            self.connected = False
            return None
    
    def debug_node_remotely(self, node_function: Callable, state: State, node_name: str) -> State:
        """Debug node with remote debugging"""
        # Send state to remote debugger
        self.send_state(state, node_name)
        
        # Wait for command
        command = self.receive_command()
        
        if command and command.get("action") == "inspect":
            print(f"Remote inspection requested for {node_name}")
            self.send_state(state, node_name)
        
        # Execute node
        try:
            result_state = node_function(state)
        except Exception as e:
            self.send_state({"error": str(e)}, node_name)
            raise
        
        return result_state
```

### 6.3 Automated Debugging

Automate debugging for common issues.

```python
class AutomatedDebugger:
    def __init__(self):
        self.known_issues = []
        self.automatic_fixes = []
    
    def add_known_issue(self, issue_detector: Callable[[State], bool], fix_function: Callable[[State], State], description: str) -> None:
        """Add known issue and fix"""
        self.known_issues.append({
            "detector": issue_detector,
            "fix": fix_function,
            "description": description
        })
    
    def debug_automatically(self, state: State, node_name: str) -> tuple[State, bool]:
        """Automatically debug and fix issues"""
        for issue in self.known_issues:
            if issue["detector"](state):
                print(f"Automatic fix applied: {issue["description"]}")
                fixed_state = issue["fix"](state)
                return fixed_state, True
        
        return state, False
    
    def add_common_fixes(self) -> None:
        """Add common debugging fixes"""
        # Add fix for missing required fields
        def missing_fields_detector(state: State) -> bool:
            required_fields = ["input", "context"]
            return not all(field in state for field in required_fields)
        
        def missing_fields_fix(state: State) -> State:
            if "input" not in state:
                state["input"] = "default_input"
            if "context" not in state:
                state["context"] = "default_context"
            return state
        
        self.add_known_issue(
            missing_fields_detector,
            missing_fields_fix,
            "Missing required fields in state"
        )
        
        # Add fix for type errors
        def type_error_detector(state: State) -> bool:
            # Simple type checking
            if "count" in state and not isinstance(state["count"], int):
                return True
            return False
        
        def type_error_fix(state: State) -> State:
            if "count" in state and not isinstance(state["count"], int):
                try:
                    state["count"] = int(state["count"])
                except (ValueError, TypeError):
                    state["count"] = 0
            return state
        
        self.add_known_issue(
            type_error_detector,
            type_error_fix,
            "Type error in state field"
        )
```

---

## Best Practices

### 7.1 Debugging Workflow

Follow a systematic approach to debugging.

```python
def systematic_debugging_workflow(graph: StateGraph, initial_state: State) -> None:
    """Systematic debugging workflow"""
    print("Starting systematic debugging workflow...")
    
    # Step 1: Verify graph structure
    print("1. Verifying graph structure...")
    verify_graph_structure(graph)
    
    # Step 2: Test individual nodes
    print("\n2. Testing individual nodes...")
    test_individual_nodes(graph)
    
    # Step 3: Check state flow
    print("\n3. Checking state flow...")
    debug_state_flow(graph, initial_state)
    
    # Step 4: Monitor performance
    print("\n4. Monitoring performance...")
    debug_performance(graph, initial_state)
    
    # Step 5: Test with edge cases
    print("\n5. Testing with edge cases...")
    test_edge_cases(graph, initial_state)
    
    print("\nDebugging workflow completed!")
```

### 7.2 Debugging Checklist

Use this checklist for thorough debugging.

```python
class DebuggingChecklist:
    def __init__(self):
        self.checks = []
    
    def add_check(self, check_function: Callable, description: str) -> None:
        """Add debugging check"""
        self.checks.append({
            "function": check_function,
            "description": description
        })
    
    def run_checks(self, graph: StateGraph, state: State) -> dict:
        """Run all debugging checks"""
        results = {}
        
        for check in self.checks:
            try:
                result = check["function"](graph, state)
                results[check["description"]] = {
                    "passed": result is not False,
                    "details": result if result is not True else "Passed"
                }
            except Exception as e:
                results[check["description"]] = {
                    "passed": False,
                    "details": f"Error: {e}"
                }
        
        return results
    
    def print_summary(self, results: dict) -> None:
        """Print debugging summary"""
        print("Debugging Checklist Results:")
        print("=" * 50)
        
        passed = 0
        total = len(results)
        
        for description, result in results.items():
            status = "✓" if result["passed"] else "✗"
            print(f"{status} {description}: {result['details']}")
            if result["passed"]:
                passed += 1
        
        print(f"\nSummary: {passed}/{total} checks passed ({passed/total*100:.1f}%)")
```

### 7.3 Production Debugging

Debugging considerations for production environments.

```python
class ProductionDebugger:
    def __init__(self):
        self.debug_enabled = False
        self.debug_level = "INFO"
        self.error_threshold = 5
    
    def enable_production_debugging(self, debug_level: str = "WARNING") -> None:
        """Enable production debugging"""
        self.debug_enabled = True
        self.debug_level = debug_level
        
        # Configure logging
        logging.basicConfig(
            level=getattr(logging, debug_level),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        
        print(f"Production debugging enabled at level: {debug_level}")
    
    def monitor_error_rate(self, error_count: int, time_window: float) -> bool:
        """Monitor error rate for production"""
        error_rate = error_count / time_window
        
        if error_rate > self.error_threshold:
            logging.warning(f"High error rate detected: {error_rate:.2f} errors/sec")
            return True
        
        return False
    
    def safe_debug_operation(self, operation: Callable, *args, **kwargs) -> Any:
        """Safe debug operation for production"""
        try:
            if self.debug_enabled:
                logging.debug(f"Executing operation: {operation.__name__}")
            
            result = operation(*args, **kwargs)
            
            if self.debug_enabled:
                logging.debug(f"Operation {operation.__name__} completed successfully")
            
            return result
            
        except Exception as e:
            logging.error(f"Error in operation {operation.__name__}: {e}")
            raise
```

---

## Conclusion

Debugging LangGraph applications requires a systematic approach combining multiple techniques:

1. **Start with basic tools** - Use built-in debug mode and state inspection
2. **Visualize the flow** - Use graph and execution visualization
3. **Monitor performance** - Track execution times and memory usage
4. **Test in isolation** - Debug individual nodes before the full graph
5. **Use automation** - Implement automated debugging for common issues
6. **Consider production** - Adapt debugging for production environments

Remember to:
- Always validate state transformations
- Monitor performance metrics
- Test with edge cases and error conditions
- Document debugging findings for future reference
- Use systematic debugging workflows

The debugging techniques covered in this guide provide a comprehensive toolkit for identifying and resolving issues in LangGraph applications, from simple state inspection to advanced remote debugging and automated issue detection.