# LangGraph Conditional Branching Guide

## Overview

This guide covers comprehensive conditional branching patterns in LangGraph, including conditional edges, dynamic routing, state-based branching, and best practices for building flexible, adaptive agent architectures.

---

## Core Conditional Branching Concepts

### 1.1 Basic Conditional Edges

Conditional edges allow routing to different nodes based on state conditions.

#### 1.1.1 Simple Conditional Branching

```python
from typing import TypedDict, Literal
from langgraph.graph import StateGraph, END

class BranchState(TypedDict):
    input: str
    confidence: float | None
    category: str | None
    result: str | None


def confidence_condition(state: BranchState) -> Literal["high", "medium", "low", "end"]:
    """Route based on confidence score"""
    confidence = state.get("confidence", 0)
    
    if confidence > 0.9:
        return "high"
    elif confidence > 0.7:
        return "medium"
    elif confidence > 0.5:
        return "low"
    return "end"


def category_condition(state: BranchState) -> Literal["research", "coding", "general", "end"]:
    """Route based on input category"""
    input_lower = state.get("input", "").lower()
    
    if "paper" in input_lower or "research" in input_lower:
        return "research"
    elif "code" in input_lower or "implement" in input_lower:
        return "coding"
    elif "exit" in input_lower or "quit" in input_lower:
        return "end"
    return "general"


def create_conditional_graph() -> StateGraph:
    """Create graph with conditional branching"""
    graph = StateGraph(BranchState)
    
    # Add nodes
    graph.add_node("categorize", categorize_node)
    graph.add_node("high_confidence", high_confidence_node)
    graph.add_node("medium_confidence", medium_confidence_node)
    graph.add_node("low_confidence", low_confidence_node)
    graph.add_node("research", research_node)
    graph.add_node("coding", coding_node)
    graph.add_node("general", general_node)
    graph.add_node("end", end_node)
    
    # Set entry point
    graph.set_entry_point("categorize")
    
    # Conditional edges for confidence-based routing
    graph.add_conditional_edges(
        "categorize",
        confidence_condition,
        {
            "high": "high_confidence",
            "medium": "medium_confidence",
            "low": "low_confidence",
            "end": "end"
        }
    )
    
    # Conditional edges for category-based routing
    graph.add_conditional_edges(
        "high_confidence",
        category_condition,
        {
            "research": "research",
            "coding": "coding",
            "general": "general",
            "end": "end"
        }
    )
    
    graph.add_conditional_edges(
        "medium_confidence",
        category_condition,
        {
            "research": "research",
            "coding": "coding",
            "general": "general",
            "end": "end"
        }
    )
    
    graph.add_conditional_edges(
        "low_confidence",
        category_condition,
        {
            "research": "research",
            "coding": "coding",
            "general": "general",
            "end": "end"
        }
    )
    
    # Terminal edges
    graph.add_edge("research", "end")
    graph.add_edge("coding", "end")
    graph.add_edge("general", "end")
    graph.add_edge("end", END)
    
    return graph
```

#### 1.1.2 Multiple Conditional Edges

```python
class MultiConditionState(TypedDict):
    input: str
    priority: int | None
    user_type: str | None
    time_of_day: str | None
    result: str | None


def priority_condition(state: MultiConditionState) -> Literal["high", "medium", "low", "end"]:
    """Route based on priority"""
    priority = state.get("priority", 0)
    
    if priority >= 3:
        return "high"
    elif priority >= 2:
        return "medium"
    elif priority >= 1:
        return "low"
    return "end"


def user_type_condition(state: MultiConditionState) -> Literal["admin", "premium", "free", "end"]:
    """Route based on user type"""
    user_type = state.get("user_type", "free")
    
    if user_type == "admin":
        return "admin"
    elif user_type == "premium":
        return "premium"
    elif user_type == "free":
        return "free"
    return "end"


def time_of_day_condition(state: MultiConditionState) -> Literal["business", "personal", "end"]:
    """Route based on time of day"""
    time_of_day = state.get("time_of_day", "business")
    
    if time_of_day in ["morning", "afternoon"]:
        return "business"
    elif time_of_day in ["evening", "night"]:
        return "personal"
    return "end"


def create_multi_condition_graph() -> StateGraph:
    """Create graph with multiple conditional edges"""
    graph = StateGraph(MultiConditionState)
    
    # Add nodes
    graph.add_node("initial", initial_node)
    graph.add_node("priority_router", priority_router_node)
    graph.add_node("user_router", user_router_node)
    graph.add_node("time_router", time_router_node)
    graph.add_node("high_priority", high_priority_node)
    graph.add_node("medium_priority", medium_priority_node)
    graph.add_node("low_priority", low_priority_node)
    graph.add_node("admin", admin_node)
    graph.add_node("premium", premium_node)
    graph.add_node("free", free_node)
    graph.add_node("business", business_node)
    graph.add_node("personal", personal_node)
    graph.add_node("end", end_node)
    
    # Set entry point
    graph.set_entry_point("initial")
    
    # Priority-based routing
    graph.add_conditional_edges(
        "initial",
        priority_condition,
        {
            "high": "priority_router",
            "medium": "priority_router",
            "low": "priority_router",
            "end": "end"
        }
    )
    
    # Priority router to specific priority nodes
    graph.add_conditional_edges(
        "priority_router",
        lambda state: state.get("priority", 0),
        {
            3: "high_priority",
            2: "medium_priority",
            1: "low_priority"
        }
    )
    
    # User type routing from priority nodes
    graph.add_conditional_edges(
        "high_priority",
        user_type_condition,
        {
            "admin": "admin",
            "premium": "premium",
            "free": "free"
        }
    )
    
    graph.add_conditional_edges(
        "medium_priority",
        user_type_condition,
        {
            "admin": "admin",
            "premium": "premium",
            "free": "free"
        }
    )
    
    graph.add_conditional_edges(
        "low_priority",
        user_type_condition,
        {
            "admin": "admin",
            "premium": "premium",
            "free": "free"
        }
    )
    
    # Time of day routing from user type nodes
    graph.add_conditional_edges(
        "admin",
        time_of_day_condition,
        {
            "business": "business",
            "personal": "personal"
        }
    )
    
    graph.add_conditional_edges(
        "premium",
        time_of_day_condition,
        {
            "business": "business",
            "personal": "personal"
        }
    )
    
    graph.add_conditional_edges(
        "free",
        time_of_day_condition,
        {
            "business": "business",
            "personal": "personal"
        }
    )
    
    # Terminal edges
    graph.add_edge("business", "end")
    graph.add_edge("personal", "end")
    graph.add_edge("end", END)
    
    return graph
```

### 1.2 Dynamic Edge Creation

Create edges dynamically based on runtime conditions.

#### 1.2.1 Dynamic Router Function

```python
from typing import Callable, Dict, Any

class DynamicRouter:
    def __init__(self):
        self.routes = {}
    
    def add_route(self, condition: Callable[[Dict], str], target: str):
        """Add route with condition"""
        self.routes[condition] = target
    
    def get_route(self, state: Dict) -> str | None:
        """Get route based on state"""
        for condition, target in self.routes.items():
            if condition(state):
                return target
        return None

class DynamicRouterNode:
    def __init__(self):
        self.router = DynamicRouter()
        self.default_route = "default_node"
    
    def configure_routes(self) -> None:
        """Configure dynamic routes"""
        # Route based on confidence
        self.router.add_route(
            lambda state: state.get("confidence", 0) > 0.8,
            "high_confidence_node"
        )
        
        # Route based on user type
        self.router.add_route(
            lambda state: state.get("user_type") == "admin",
            "admin_node"
        )
        
        # Route based on time of day
        self.router.add_route(
            lambda state: state.get("time_of_day") in ["morning", "afternoon"],
            "business_node"
        )
        
        # Route based on input length
        self.router.add_route(
            lambda state: len(state.get("input", "")) > 1000,
            "long_input_node"
        )
    
    def route(self, state: Dict) -> str:
        """Route to appropriate node"""
        route = self.router.get_route(state)
        return route if route else self.default_route

class DynamicGraph:
    def __init__(self):
        self.router_node = DynamicRouterNode()
        self.router_node.configure_routes()
        self.graph = StateGraph(DynamicState)
        
        # Add all possible nodes
        self.graph.add_node("router", self.router_node.route)
        self.graph.add_node("high_confidence_node", high_confidence_node)
        self.graph.add_node("admin_node", admin_node)
        self.graph.add_node("business_node", business_node)
        self.graph.add_node("long_input_node", long_input_node)
        self.graph.add_node("default_node", default_node)
        self.graph.add_node("end", end_node)
        
        self.graph.set_entry_point("router")
        
        # Add dynamic edge
        self.graph.add_dynamic_edge("router", self.router_node.route)
        self.graph.add_edge("high_confidence_node", "end")
        self.graph.add_edge("admin_node", "end")
        self.graph.add_edge("business_node", "end")
        self.graph.add_edge("long_input_node", "end")
        self.graph.add_edge("default_node", "end")
        self.graph.add_edge("end", END)
    
    def get_graph(self) -> StateGraph:
        """Get configured graph"""
        return self.graph

# Usage
def create_dynamic_graph() -> StateGraph:
    """Create graph with dynamic routing"""
    dynamic_graph = DynamicGraph()
    return dynamic_graph.get_graph()
```

#### 1.2.2 State-Based Edge Creation

```python
class StateBasedEdgeCreator:
    def __init__(self):
        self.edge_config = {}
    
    def configure_edges(self, state: Dict) -> list:
        """Configure edges based on state"""
        edges = []
        
        # Basic routing
        if state.get("priority") == "high":
            edges.append(("high_priority", "critical_processing"))
            edges.append(("critical_processing", "review"))
        elif state.get("priority") == "medium":
            edges.append(("medium_priority", "standard_processing"))
            edges.append(("standard_processing", "review"))
        else:
            edges.append(("low_priority", "basic_processing"))
            edges.append(("basic_processing", "review"))
        
        # User-specific routing
        if state.get("user_type") == "admin":
            edges.append(("review", "admin_review"))
        elif state.get("user_type") == "premium":
            edges.append(("review", "premium_review"))
        else:
            edges.append(("review", "standard_review"))
        
        # Time-based routing
        time_of_day = state.get("time_of_day", "business")
        if time_of_day in ["morning", "afternoon"]:
            edges.append(("standard_review", "business_processing"))
        else:
            edges.append(("standard_review", "personal_processing"))
        
        # Add terminal edges
        edges.append(("admin_review", "end"))
        edges.append(("premium_review", "end"))
        edges.append(("business_processing", "end"))
        edges.append(("personal_processing", "end"))
        
        return edges

class StateBasedGraph:
    def __init__(self):
        self.edge_creator = StateBasedEdgeCreator()
        self.graph = StateGraph(StateBasedState)
        
        # Add all possible nodes
        self.graph.add_node("initial", initial_node)
        self.graph.add_node("high_priority", high_priority_node)
        self.graph.add_node("medium_priority", medium_priority_node)
        self.graph.add_node("low_priority", low_priority_node)
        self.graph.add_node("critical_processing", critical_processing_node)
        self.graph.add_node("standard_processing", standard_processing_node)
        self.graph.add_node("basic_processing", basic_processing_node)
        self.graph.add_node("review", review_node)
        self.graph.add_node("admin_review", admin_review_node)
        self.graph.add_node("premium_review", premium_review_node)
        self.graph.add_node("standard_review", standard_review_node)
        self.graph.add_node("business_processing", business_processing_node)
        self.graph.add_node("personal_processing", personal_processing_node)
        self.graph.add_node("end", end_node)
        
        self.graph.set_entry_point("initial")
        
        # Add dynamic edge configuration
        self.graph.add_dynamic_edge_config("initial", self.edge_creator.configure_edges)
        
        return self.graph
    
    def get_graph(self) -> StateGraph:
        """Get configured graph"""
        return self.graph

# Usage
def create_state_based_graph() -> StateGraph:
    """Create graph with state-based edge configuration"""
    state_based_graph = StateBasedGraph()
    return state_based_graph.get_graph()
```

---

## Advanced Conditional Branching Patterns

### 2.1 Complex Conditional Logic

Implement sophisticated branching logic with multiple conditions.

#### 2.1.1 Nested Conditional Branching

```python
class NestedConditionState(TypedDict):
    input: str
    user_type: str | None
    priority: int | None
    time_of_day: str | None
    device_type: str | None
    location: str | None
    result: str | None


def nested_condition_logic(state: NestedConditionState) -> str:
    """Complex nested conditional logic"""
    user_type = state.get("user_type")
    priority = state.get("priority", 0)
    time_of_day = state.get("time_of_day")
    device_type = state.get("device_type")
    location = state.get("location")
    
    # First level: User type
    if user_type == "admin":
        # Admin routing
        if priority >= 3:
            # High priority admin
            if time_of_day in ["morning", "afternoon"]:
                return "admin_high_priority_business"
            else:
                return "admin_high_priority_personal"
        elif priority >= 2:
            # Medium priority admin
            if device_type == "mobile":
                return "admin_medium_priority_mobile"
            else:
                return "admin_medium_priority_desktop"
        else:
            # Low priority admin
            return "admin_low_priority"
            
    elif user_type == "premium":
        # Premium user routing
        if priority >= 2:
            # High/medium priority premium
            if location == "office":
                return "premium_office"
            elif location == "home":
                return "premium_home"
            else:
                return "premium_mobile"
        else:
            # Low priority premium
            return "premium_basic"
            
    else:
        # Regular user routing
        if priority >= 1:
            # High priority regular
            if time_of_day in ["morning", "afternoon"]:
                return "regular_high_priority_business"
            else:
                return "regular_high_priority_personal"
        else:
            # Low priority regular
            if device_type == "mobile":
                return "regular_low_priority_mobile"
            else:
                return "regular_low_priority_desktop"


def create_nested_condition_graph() -> StateGraph:
    """Create graph with nested conditional branching"""
    graph = StateGraph(NestedConditionState)
    
    # Add all possible nodes
    graph.add_node("initial", initial_node)
    graph.add_node("admin_high_priority_business", admin_high_priority_business_node)
    graph.add_node("admin_high_priority_personal", admin_high_priority_personal_node)
    graph.add_node("admin_medium_priority_mobile", admin_medium_priority_mobile_node)
    graph.add_node("admin_medium_priority_desktop", admin_medium_priority_desktop_node)
    graph.add_node("admin_low_priority", admin_low_priority_node)
    graph.add_node("premium_office", premium_office_node)
    graph.add_node("premium_home", premium_home_node)
    graph.add_node("premium_mobile", premium_mobile_node)
    graph.add_node("premium_basic", premium_basic_node)
    graph.add_node("regular_high_priority_business", regular_high_priority_business_node)
    graph.add_node("regular_high_priority_personal", regular_high_priority_personal_node)
    graph.add_node("regular_low_priority_mobile", regular_low_priority_mobile_node)
    graph.add_node("regular_low_priority_desktop", regular_low_priority_desktop_node)
    graph.add_node("end", end_node)
    
    graph.set_entry_point("initial")
    
    # Nested conditional edges
    graph.add_conditional_edges(
        "initial",
        nested_condition_logic,
        {
            "admin_high_priority_business": "admin_high_priority_business",
            "admin_high_priority_personal": "admin_high_priority_personal",
            "admin_medium_priority_mobile": "admin_medium_priority_mobile",
            "admin_medium_priority_desktop": "admin_medium_priority_desktop",
            "admin_low_priority": "admin_low_priority",
            "premium_office": "premium_office",
            "premium_home": "premium_home",
            "premium_mobile": "premium_mobile",
            "premium_basic": "premium_basic",
            "regular_high_priority_business": "regular_high_priority_business",
            "regular_high_priority_personal": "regular_high_priority_personal",
            "regular_low_priority_mobile": "regular_low_priority_mobile",
            "regular_low_priority_desktop": "regular_low_priority_desktop",
            "end": "end"
        }
    )
    
    # Terminal edges
    graph.add_edge("admin_high_priority_business", "end")
    graph.add_edge("admin_high_priority_personal", "end")
    graph.add_edge("admin_medium_priority_mobile", "end")
    graph.add_edge("admin_medium_priority_desktop", "end")
    graph.add_edge("admin_low_priority", "end")
    graph.add_edge("premium_office", "end")
    graph.add_edge("premium_home", "end")
    graph.add_edge("premium_mobile", "end")
    graph.add_edge("premium_basic", "end")
    graph.add_edge("regular_high_priority_business", "end")
    graph.add_edge("regular_high_priority_personal", "end")
    graph.add_edge("regular_low_priority_mobile", "end")
    graph.add_edge("regular_low_priority_desktop", "end")
    graph.add_edge("end", END)
    
    return graph
```

#### 2.1.2 Rule-Based Branching

```python
from typing import Dict, Any, Callable
from dataclasses import dataclass
from enum import Enum

class RuleType(Enum):
    PRIORITY = "priority"
    USER_TYPE = "user_type"
    TIME_OF_DAY = "time_of_day"
    DEVICE_TYPE = "device_type"
    LOCATION = "location"
    INPUT_LENGTH = "input_length"

@dataclass
class Rule:
    rule_type: RuleType
    condition: Callable[[Any], bool]
    target: str

class RuleBasedRouter:
    def __init__(self):
        self.rules = []
        self.default_route = "default_node"
    
    def add_rule(self, rule_type: RuleType, condition: Callable[[Any], bool], target: str):
        """Add routing rule"""
        self.rules.append(Rule(rule_type, condition, target))
    
    def evaluate_rules(self, state: Dict) -> str | None:
        """Evaluate rules and return matching route"""
        for rule in self.rules:
            try:
                if rule.condition(state):
                    return rule.target
            except Exception:
                continue
        return None
    
    def route(self, state: Dict) -> str:
        """Route using rule-based system"""
        route = self.evaluate_rules(state)
        return route if route else self.default_route

class RuleBasedGraph:
    def __init__(self):
        self.router = RuleBasedRouter()
        self.configure_rules()
        self.graph = StateGraph(RuleBasedState)
        
        # Add all possible nodes
        self.graph.add_node("router", self.router.route)
        self.graph.add_node("high_priority", high_priority_node)
        self.graph.add_node("medium_priority", medium_priority_node)
        self.graph.add_node("low_priority", low_priority_node)
        self.graph.add_node("admin", admin_node)
        self.graph.add_node("premium", premium_node)
        self.graph.add_node("free", free_node)
        self.graph.add_node("business", business_node)
        self.graph.add_node("personal", personal_node)
        self.graph.add_node("default", default_node)
        self.graph.add_node("end", end_node)
        
        self.graph.set_entry_point("router")
        
        # Add dynamic edge
        self.graph.add_dynamic_edge("router", self.router.route)
        
        # Add static edges for all possible routes
        self.graph.add_edge("high_priority", "end")
        self.graph.add_edge("medium_priority", "end")
        self.graph.add_edge("low_priority", "end")
        self.graph.add_edge("admin", "end")
        self.graph.add_edge("premium", "end")
        self.graph.add_edge("free", "end")
        self.graph.add_edge("business", "end")
        self.graph.add_edge("personal", "end")
        self.graph.add_edge("default", "end")
        self.graph.add_edge("end", END)
    
    def configure_rules(self) -> None:
        """Configure routing rules"""
        # Priority rules
        self.router.add_rule(
            RuleType.PRIORITY,
            lambda state: state.get("priority", 0) >= 3,
            "high_priority"
        )
        
        self.router.add_rule(
            RuleType.PRIORITY,
            lambda state: state.get("priority", 0) >= 2,
            "medium_priority"
        )
        
        self.router.add_rule(
            RuleType.PRIORITY,
            lambda state: state.get("priority", 0) >= 1,
            "low_priority"
        )
        
        # User type rules
        self.router.add_rule(
            RuleType.USER_TYPE,
            lambda state: state.get("user_type") == "admin",
            "admin"
        )
        
        self.router.add_rule(
            RuleType.USER_TYPE,
            lambda state: state.get("user_type") == "premium",
            "premium"
        )
        
        self.router.add_rule(
            RuleType.USER_TYPE,
            lambda state: state.get("user_type") == "free",
            "free"
        )
        
        # Time of day rules
        self.router.add_rule(
            RuleType.TIME_OF_DAY,
            lambda state: state.get("time_of_day") in ["morning", "afternoon"],
            "business"
        )
        
        self.router.add_rule(
            RuleType.TIME_OF_DAY,
            lambda state: state.get("time_of_day") in ["evening", "night"],
            "personal"
        )
        
        # Input length rules
        self.router.add_rule(
            RuleType.INPUT_LENGTH,
            lambda state: len(state.get("input", "")) > 1000,
            "long_input"
        )
        
        # Device type rules
        self.router.add_rule(
            RuleType.DEVICE_TYPE,
            lambda state: state.get("device_type") == "mobile",
            "mobile"
        )
        
        # Location rules
        self.router.add_rule(
            RuleType.LOCATION,
            lambda state: state.get("location") == "office",
            "office"
        )

# Usage
def create_rule_based_graph() -> StateGraph:
    """Create graph with rule-based routing"""
    rule_based_graph = RuleBasedGraph()
    return rule_based_graph.graph
```

### 2.2 State-Based Branching

Branch based on complex state conditions and patterns.

#### 2.2.1 State Pattern Matching

```python
from typing import TypedDict, Dict, Any, Callable, List
from dataclasses import dataclass
from enum import Enum

class StatePatternType(Enum):
    CONTAINS = "contains"
    EQUALS = "equals"
    GREATER_THAN = "greater_than"
    LESS_THAN = "less_than"
    IN_LIST = "in_list"
    MATCHES_REGEX = "matches_regex"

@dataclass
class StatePattern:
    field: str
    pattern_type: StatePatternType
    value: Any
    target: str

class StatePatternRouter:
    def __init__(self):
        self.patterns = []
        self.default_route = "default_node"
    
    def add_pattern(self, field: str, pattern_type: StatePatternType, value: Any, target: str):
        """Add state pattern"""
        self.patterns.append(StatePattern(field, pattern_type, value, target))
    
    def match_pattern(self, state: Dict, pattern: StatePattern) -> bool:
        """Check if state matches pattern"""
        field_value = state.get(pattern.field)
        
        if field_value is None:
            return False
        
        try:
            match pattern.pattern_type:
                case StatePatternType.CONTAINS:
                    return pattern.value in field_value
                case StatePatternType.EQUALS:
                    return field_value == pattern.value
                case StatePatternType.GREATER_THAN:
                    return field_value > pattern.value
                case StatePatternType.LESS_THAN:
                    return field_value < pattern.value
                case StatePatternType.IN_LIST:
                    return field_value in pattern.value
                case StatePatternType.MATCHES_REGEX:
                    import re
                    return re.match(pattern.value, field_value) is not None
        except Exception:
            return False
    
    def route(self, state: Dict) -> str:
        """Route based on state patterns"""
        for pattern in self.patterns:
            if self.match_pattern(state, pattern):
                return pattern.target
        
        return self.default_route

class StatePatternGraph:
    def __init__(self):
        self.router = StatePatternRouter()
        self.configure_patterns()
        self.graph = StateGraph(StatePatternState)
        
        # Add all possible nodes
        self.graph.add_node("router", self.router.route)
        self.graph.add_node("high_priority", high_priority_node)
        self.graph.add_node("medium_priority", medium_priority_node)
        self.graph.add_node("low_priority", low_priority_node)
        self.graph.add_node("admin", admin_node)
        self.graph.add_node("premium", premium_node)
        self.graph.add_node("free", free_node)
        self.graph.add_node("business", business_node)
        self.graph.add_node("personal", personal_node)
        self.graph.add_node("long_input", long_input_node)
        self.graph.add_node("mobile", mobile_node)
        self.graph.add_node("office", office_node)
        self.graph.add_node("default", default_node)
        self.graph.add_node("end", end_node)
        
        self.graph.set_entry_point("router")
        
        # Add dynamic edge
        self.graph.add_dynamic_edge("router", self.router.route)
        
        # Add static edges for all possible routes
        self.graph.add_edge("high_priority", "end")
        self.graph.add_edge("medium_priority", "end")
        self.graph.add_edge("low_priority", "end")
        self.graph.add_edge("admin", "end")
        self.graph.add_edge("premium", "end")
        self.graph.add_edge("free", "end")
        self.graph.add_edge("business", "end")
        self.graph.add_edge("personal", "end")
        self.graph.add_edge("long_input", "end")
        self.graph.add_edge("mobile", "end")
        self.graph.add_edge("office", "end")
        self.graph.add_edge("default", "end")
        self.graph.add_edge("end", END)
    
    def configure_patterns(self) -> None:
        """Configure state patterns"""
        # Priority patterns
        self.router.add_pattern("priority", StatePatternType.GREATER_THAN, 2, "high_priority")
        self.router.add_pattern("priority", StatePatternType.GREATER_THAN, 1, "medium_priority")
        self.router.add_pattern("priority", StatePatternType.GREATER_THAN, 0, "low_priority")
        
        # User type patterns
        self.router.add_pattern("user_type", StatePatternType.EQUALS, "admin", "admin")
        self.router.add_pattern("user_type", StatePatternType.EQUALS, "premium", "premium")
        self.router.add_pattern("user_type", StatePatternType.EQUALS, "free", "free")
        
        # Time of day patterns
        self.router.add_pattern("time_of_day", StatePatternType.CONTAINS, "morning", "business")
        self.router.add_pattern("time_of_day", StatePatternType.CONTAINS, "afternoon", "business")
        self.router.add_pattern("time_of_day", StatePatternType.CONTAINS, "evening", "personal")
        self.router.add_pattern("time_of_day", StatePatternType.CONTAINS, "night", "personal")
        
        # Input length patterns
        self.router.add_pattern("input", StatePatternType.GREATER_THAN, 1000, "long_input")
        
        # Device type patterns
        self.router.add_pattern("device_type", StatePatternType.EQUALS, "mobile", "mobile")
        
        # Location patterns
        self.router.add_pattern("location", StatePatternType.EQUALS, "office", "office")

# Usage
def create_state_pattern_graph() -> StateGraph:
    """Create graph with state pattern routing"""
    state_pattern_graph = StatePatternGraph()
    return state_pattern_graph.graph
```

#### 2.2.2 State Machine Branching

```python
from typing import TypedDict, Dict, Any, Callable, List
from enum import Enum
from dataclasses import dataclass

class StateMachineState(TypedDict):
    current_state: str
    event: str
    data: Dict[str, Any]
    result: str | None
    error: str | None

class StateMachineEvent(Enum):
    START = "start"
    PROCESS = "process"
    COMPLETE = "complete"
    ERROR = "error"
    TIMEOUT = "timeout"

@dataclass
class StateTransition:
    from_state: str
    event: StateMachineEvent
    condition: Callable[[Dict], bool] | None
    to_state: str
    action: Callable[[Dict], Any] | None

class StateMachine:
    def __init__(self):
        self.transitions = []
        self.current_state = "initial"
    
    def add_transition(self, from_state: str, event: StateMachineEvent, condition: Callable[[Dict], bool] | None, to_state: str, action: Callable[[Dict], Any] | None):
        """Add state transition"""
        self.transitions.append(StateTransition(from_state, event, condition, to_state, action))
    
    def process_event(self, state: StateMachineState) -> StateMachineState:
        """Process event through state machine"""
        event = state.get("event")
        
        if not event:
            return {**state, "error": "No event specified"}
        
        # Find matching transition
        for transition in self.transitions:
            if (transition.from_state == self.current_state and
                transition.event == event and
                (transition.condition is None or transition.condition(state))):
                
                # Execute transition action
                if transition.action:
                    try:
                        result = transition.action(state)
                        return {**state, "result": result, "current_state": transition.to_state}
                    except Exception as e:
                        return {**state, "error": str(e), "current_state": "error"}
                
                # Just transition state
                return {**state, "current_state": transition.to_state}
        
        return {**state, "error": f"No transition found for event {event} from state {self.current_state}"}

class StateMachineGraph:
    def __init__(self):
        self.state_machine = StateMachine()
        self.configure_transitions()
        self.graph = StateGraph(StateMachineState)
        
        # Add all possible nodes
        self.graph.add_node("initial", self.initial_node)
        self.graph.add_node("processing", self.processing_node)
        self.graph.add_node("completed", self.completed_node)
        self.graph.add_node("error", self.error_node)
        self.graph.add_node("timeout", self.timeout_node)
        self.graph.add_node("end", end_node)
        
        self.graph.set_entry_point("initial")
        
        # Add conditional edges based on state machine
        self.graph.add_conditional_edges(
            "initial",
            lambda state: state.get("current_state") == "processing",
            {"continue": "processing", "error": "error", "timeout": "timeout"}
        )
        
        self.graph.add_conditional_edges(
            "processing",
            lambda state: state.get("current_state") == "completed",
            {"continue": "completed", "error": "error", "timeout": "timeout"}
        )
        
        self.graph.add_conditional_edges(
            "processing",
            lambda state: state.get("current_state") == "error",
            {"error": "error"}
        )
        
        self.graph.add_conditional_edges(
            "processing",
            lambda state: state.get("current_state") == "timeout",
            {"timeout": "timeout"}
        )
        
        # Terminal edges
        self.graph.add_edge("completed", "end")
        self.graph.add_edge("error", "end")
        self.graph.add_edge("timeout", "end")
        self.graph.add_edge("end", END)
    
    def configure_transitions(self) -> None:
        """Configure state machine transitions"""
        # Initial transitions
        self.state_machine.add_transition("initial", StateMachineEvent.START, None, "processing", self.start_action)
        self.state_machine.add_transition("initial", StateMachineEvent.ERROR, None, "error", self.error_action)
        
        # Processing transitions
        self.state_machine.add_transition("processing", StateMachineEvent.COMPLETE, None, "completed", self.complete_action)
        self.state_machine.add_transition("processing", StateMachineEvent.ERROR, None, "error", self.error_action)
        self.state_machine.add_transition("processing", StateMachineEvent.TIMEOUT, None, "timeout", self.timeout_action)
        
        # Error transitions
        self.state_machine.add_transition("error", StateMachineEvent.START, None, "processing", self.start_action)
        
        # Timeout transitions
        self.state_machine.add_transition("timeout", StateMachineEvent.START, None, "processing", self.start_action)
    
    def start_action(self, state: Dict) -> Any:
        """Start action"""
        return f"Processing started for {state.get("data", {})}"
    
    def complete_action(self, state: Dict) -> Any:
        """Complete action"""
        return f"Processing completed for {state.get("data", {})}"
    
    def error_action(self, state: Dict) -> Any:
        """Error action"""
        return f"Error occurred: {state.get("error")}"
    
    def timeout_action(self, state: Dict) -> Any:
        """Timeout action"""
        return f"Processing timed out for {state.get("data", {})}"
    
    def initial_node(self, state: StateMachineState) -> StateMachineState:
        """Initial node"""
        return self.state_machine.process_event({**state, "event": StateMachineEvent.START})
    
    def processing_node(self, state: StateMachineState) -> StateMachineState:
        """Processing node"""
        # Simulate processing
        if random.random() < 0.8:  # 80% success rate
            return self.state_machine.process_event({**state, "event": StateMachineEvent.COMPLETE})
        elif random.random() < 0.1:  # 10% error rate
            return self.state_machine.process_event({**state, "event": StateMachineEvent.ERROR, "error": "Processing error"})
        else:  # 10% timeout rate
            return self.state_machine.process_event({**state, "event": StateMachineEvent.TIMEOUT})
    
    def completed_node(self, state: StateMachineState) -> StateMachineState:
        """Completed node"""
        return state
    
    def error_node(self, state: StateMachineState) -> StateMachineState:
        """Error node"""
        return state
    
    def timeout_node(self, state: StateMachineState) -> StateMachineState:
        """Timeout node"""
        return state

# Usage
def create_state_machine_graph() -> StateGraph:
    """Create graph with state machine branching"""
    state_machine_graph = StateMachineGraph()
    return state_machine_graph.graph
```

---

## Advanced Conditional Branching Patterns

### 3.1 Multi-Level Branching

Implement complex multi-level branching with nested conditions.

#### 3.1.1 Hierarchical Branching

```python
class HierarchicalState(TypedDict):
    level1: str | None
    level2: str | None
    level3: str | None
    data: Dict[str, Any]
    result: str | None

class HierarchicalRouter:
    def __init__(self):
        self.level1_routes = {}
        self.level2_routes = {}
        self.level3_routes = {}
    
    def add_level1_route(self, condition: Callable[[Dict], str], target: str):
        """Add level 1 route"""
        self.level1_routes[condition] = target
    
    def add_level2_route(self, parent: str, condition: Callable[[Dict], str], target: str):
        """Add level 2 route"""
        if parent not in self.level2_routes:
            self.level2_routes[parent] = []
        self.level2_routes[parent].append((condition, target))
    
    def add_level3_route(self, parent: str, condition: Callable[[Dict], str], target: str):
        """Add level 3 route"""
        if parent not in self.level3_routes:
            self.level3_routes[parent] = []
        self.level3_routes[parent].append((condition, target))
    
    def route_level1(self, state: Dict) -> str | None:
        """Route to level 1"""
        for condition, target in self.level1_routes.items():
            if condition(state):
                return target
        return None
    
    def route_level2(self, state: Dict, level1_result: str) -> str | None:
        """Route to level 2"""
        if level1_result not in self.level2_routes:
            return None
        
        for condition, target in self.level2_routes[level1_result]:
            if condition(state):
                return target
        return None
    
    def route_level3(self, state: Dict, level2_result: str) -> str | None:
        """Route to level 3"""
        if level2_result not in self.level3_routes:
            return None
        
        for condition, target in self.level3_routes[level2_result]:
            if condition(state):
                return target
        return None
    
    def route(self, state: Dict) -> str:
        """Complete hierarchical routing"""
        level1 = self.route_level1(state)
        if not level1:
            return "default"
        
        level2 = self.route_level2(state, level1)
        if not level2:
            return level1
        
        level3 = self.route_level3(state, level2)
        if level3:
            return level3
        
        return level2

class HierarchicalGraph:
    def __init__(self):
        self.router = HierarchicalRouter()
        self.configure_routes()
        self.graph = StateGraph(HierarchicalState)
        
        # Add all possible nodes
        self.graph.add_node("initial", initial_node)
        self.graph.add_node("level1_a", level1_a_node)
        self.graph.add_node("level1_b", level1_b_node)
        self.graph.add_node("level1_c", level1_c_node)
        self.graph.add_node("level2_a1", level2_a1_node)
        self.graph.add_node("level2_a2", level2_a2_node)
        self.graph.add_node("level2_b1", level2_b1_node)
        self.graph.add_node("level2_b2", level2_b2_node)
        self.graph.add_node("level2_c1", level2_c1_node)
        self.graph.add_node("level2_c2", level2_c2_node)
        self.graph.add_node("level3_a1x", level3_a1x_node)
        self.graph.add_node("level3_a1y", level3_a1y_node)
        self.graph.add_node("level3_b2z", level3_b2z_node)
        self.graph.add_node("level3_c2w", level3_c2w_node)
        self.graph.add_node("default", default_node)
        self.graph.add_node("end", end_node)
        
        self.graph.set_entry_point("initial")
        
        # Add dynamic edge for hierarchical routing
        self.graph.add_dynamic_edge("initial", self.router.route)
        self.graph.add_dynamic_edge("level1_a", self.router.route)
        self.graph.add_dynamic_edge("level1_b", self.router.route)
        self.graph.add_dynamic_edge("level1_c", self.router.route)
        self.graph.add_dynamic_edge("level2_a1", self.router.route)
        self.graph.add_dynamic_edge("level2_a2", self.router.route)
        self.graph.add_dynamic_edge("level2_b1", self.router.route)
        self.graph.add_dynamic_edge("level2_b2", self.router.route)
        self.graph.add_dynamic_edge("level2_c1", self.router.route)
        self.graph.add_dynamic_edge("level2_c2", self.router.route)
        
        # Add static edges for terminal nodes
        self.graph.add_edge("level3_a1x", "end")
        self.graph.add_edge("level3_a1y", "end")
        self.graph.add_edge("level3_b2z", "end")
        self.graph.add_edge("level3_c2w", "end")
        self.graph.add_edge("default", "end")
        self.graph.add_edge("end", END)
    
    def configure_routes(self) -> None:
        """Configure hierarchical routes"""
        # Level 1 routes
        self.router.add_level1_route(
            lambda state: state.get("data", {}).get("category") == "a",
            "level1_a"
        )
        
        self.router.add_level1_route(
            lambda state: state.get("data", {}).get("category") == "b",
            "level1_b"
        )
        
        self.router.add_level1_route(
            lambda state: state.get("data", {}).get("category") == "c",
            "level1_c"
        )
        
        # Level 2 routes for level1_a
        self.router.add_level2_route(
            "level1_a",
            lambda state: state.get("data", {}).get("type") == "x",
            "level2_a1"
        )
        
        self.router.add_level2_route(
            "level1_a",
            lambda state: state.get("data", {}).get("type") == "y",
            "level2_a2"
        )
        
        # Level 2 routes for level1_b
        self.router.add_level2_route(
            "level1_b",
            lambda state: state.get("data", {}).get("type") == "z",
            "level2_b1"
        )
        
        self.router.add_level2_route(
            "level1_b",
            lambda state: state.get("data", {}).get("type") == "w",
            "level2_b2"
        )
        
        # Level 2 routes for level1_c
        self.router.add_level2_route(
            "level1_c",
            lambda state: state.get("data", {}).get("type") == "x",
            "level2_c1"
        )
        
        self.router.add_level2_route(
            "level1_c",
            lambda state.get("data", {}).get("type") == "y",
            "level2_c2"
        )
        
        # Level 3 routes
        self.router.add_level3_route(
            "level2_a1",
            lambda state: state.get("data", {}).get("subtype") == "x",
            "level3_a1x"
        )
        
        self.router.add_level3_route(
            "level2_a1",
            lambda state: state.get("data", {}).get("subtype") == "y",
            "level3_a1y"
        )
        
        self.router.add_level3_route(
            "level2_b2",
            lambda state: state.get("data", {}).get("subtype") == "z",
            "level3_b2z"
        )
        
        self.router.add_level3_route(
            "level2_c2",
            lambda state.get("data", {}).get("subtype") == "w",
            "level3_c2w"
        )

# Usage
def create_hierarchical_graph() -> StateGraph:
    """Create graph with hierarchical branching"""
    hierarchical_graph = HierarchicalGraph()
    return hierarchical_graph.graph
```

#### 3.1.2 Context-Aware Branching

```python
class ContextAwareState(TypedDict):
    context: Dict[str, Any]
    history: List[Dict]
    current_path: List[str]
    result: str | None

class ContextAwareRouter:
    def __init__(self):
        self.context_patterns = []
        self.history_patterns = []
        self.default_route = "default"
    
    def add_context_pattern(self, pattern: Dict[str, Any], target: str):
        """Add context pattern"""
        self.context_patterns.append((pattern, target))
    
    def add_history_pattern(self, pattern: Dict[str, Any], target: str):
        """Add history pattern"""
        self.history_patterns.append((pattern, target))
    
    def match_context(self, context: Dict, pattern: Dict) -> bool:
        """Check if context matches pattern"""
        for key, value in pattern.items():
            if key not in context or context[key] != value:
                return False
        return True
    
    def match_history(self, history: List[Dict], pattern: Dict) -> bool:
        """Check if history matches pattern"""
        # Check if pattern exists in history
        for entry in history:
            if self.match_context(entry, pattern):
                return True
        return False
    
    def route(self, state: ContextAwareState) -> str:
        """Route based on context and history"""
        # Check context patterns first
        for pattern, target in self.context_patterns:
            if self.match_context(state.get("context", {}), pattern):
                return target
        
        # Check history patterns
        for pattern, target in self.history_patterns:
            if self.match_history(state.get("history", []), pattern):
                return target
        
        return self.default_route

class ContextAwareGraph:
    def __init__(self):
        self.router = ContextAwareRouter()
        self.configure_patterns()
        self.graph = StateGraph(ContextAwareState)
        
        # Add all possible nodes
        self.graph.add_node("initial", initial_node)
        self.graph.add_node("context_a", context_a_node)
        self.graph.add_node("context_b", context_b_node)
        self.graph.add_node("context_c", context_c_node)
        self.graph.add_node("history_a", history_a_node)
        self.graph.add_node("history_b", history_b_node)
        self.graph.add_node("default", default_node)
        self.graph.add_node("end", end_node)
        
        self.graph.set_entry_point("initial")
        
        # Add dynamic edge for context-aware routing
        self.graph.add_dynamic_edge("initial", self.router.route)
        self.graph.add_dynamic_edge("context_a", self.router.route)
        self.graph.add_dynamic_edge("context_b", self.router.route)
        self.graph.add_dynamic_edge("context_c", self.router.route)
        self.graph.add_dynamic_edge("history_a", self.router.route)
        self.graph.add_dynamic_edge("history_b", self.router.route)
        
        # Add static edges for terminal nodes
        self.graph.add_edge("context_a", "end")
        self.graph.add_edge("context_b", "end")
        self.graph.add_edge("context_c", "end")
        self.graph.add_edge("history_a", "end")
        self.graph.add_edge("history_b", "end")
        self.graph.add_edge("default", "end")
        self.graph.add_edge("end", END)
    
    def configure_patterns(self) -> None:
        """Configure context and history patterns"""
        # Context patterns
        self.router.add_context_pattern(
            {"user_type": "admin", "priority": "high"},
            "context_a"
        )
        
        self.router.add_context_pattern(
            {"user_type": "premium", "time_of_day": "business"},
            "context_b"
        )
        
        self.router.add_context_pattern(
            {"device_type": "mobile", "location": "home"},
            "context_c"
        )
        
        # History patterns
        self.router.add_history_pattern(
            {"action": "login", "success": True},
            "history_a"
        )
        
        self.router.add_history_pattern(
            {"action": "purchase", "amount": {"$gt": 100}},
            "history_b"
        )

# Usage
def create_context_aware_graph() -> StateGraph:
    """Create graph with context-aware branching"""
    context_aware_graph = ContextAwareGraph()
    return context_aware_graph.graph
```

---

## Performance Considerations

### 4.1 Efficient Conditional Evaluation

Optimize conditional evaluation for performance.

#### 4.1.1 Short-Circuit Evaluation

```python
class EfficientConditionRouter:
    def __init__(self):
        self.conditions = []
        self.sorted_conditions = []
    
    def add_condition(self, condition: Callable[[Dict], bool], target: str, priority: int = 0):
        """Add condition with priority"""
        self.conditions.append({
            "condition": condition,
            "target": target,
            "priority": priority
        })
        
        # Sort conditions by priority (higher priority first)
        self.sorted_conditions = sorted(
            self.conditions,
            key=lambda x: x["priority"],
            reverse=True
        )
    
    def route(self, state: Dict) -> str:
        """Route using efficient condition evaluation"""
        # Evaluate high-priority conditions first
        for condition in self.sorted_conditions:
            if condition["condition"](state):
                return condition["target"]
        
        return "default"
    
    def optimize_conditions(self) -> None:
        """Optimize conditions for performance"""
        # Group conditions by common patterns
        condition_groups = {}
        
        for condition in self.conditions:
            # Create signature for condition
            signature = self.get_condition_signature(condition["condition"])
            
            if signature not in condition_groups:
                condition_groups[signature] = []
            
            condition_groups[signature].append(condition)
        
        # Reorder conditions based on expected frequency
        optimized_conditions = []
        
        for signature, group in condition_groups.items():
            # Sort by expected frequency (most frequent first)
            sorted_group = sorted(group, key=self.get_expected_frequency, reverse=True)
            optimized_conditions.extend(sorted_group)
        
        self.sorted_conditions = optimized_conditions
    
    def get_condition_signature(self, condition: Callable) -> str:
        """Get signature for condition"""
        # This would analyze the condition function to determine
        # what state fields it accesses
        return "generic_signature"
    
    def get_expected_frequency(self, condition: Dict) -> float:
        """Get expected frequency for condition"""
        # This would return expected frequency based on historical data
        return 0.5  # Default frequency

class EfficientGraph:
    def __init__(self):
        self.router = EfficientConditionRouter()
        self.configure_conditions()
        self.graph = StateGraph(EfficientState)
        
        # Add all possible nodes
        self.graph.add_node("router", self.router.route)
        self.graph.add_node("high_frequency", high_frequency_node)
        self.graph.add_node("medium_frequency", medium_frequency_node)
        self.graph.add_node("low_frequency", low_frequency_node)
        self.graph.add_node("default", default_node)
        self.graph.add_node("end", end_node)
        
        self.router.optimize_conditions()
        
        self.graph.set_entry_point("router")
        self.graph.add_dynamic_edge("router", self.router.route)
        
        # Add static edges for terminal nodes
        self.graph.add_edge("high_frequency", "end")
        self.graph.add_edge("medium_frequency", "end")
        self.graph.add_edge("low_frequency", "end")
        self.graph.add_edge("default", "end")
        self.graph.add_edge("end", END)
    
    def configure_conditions(self) -> None:
        """Configure efficient conditions"""
        # High frequency conditions first
        self.router.add_condition(
            lambda state: state.get("user_type") == "admin",
            "high_frequency",
            priority=10
        )
        
        self.router.add_condition(
            lambda state: state.get("priority", 0) >= 3,
            "high_frequency",
            priority=10
        )
        
        # Medium frequency conditions
        self.router.add_condition(
            lambda state: state.get("time_of_day") in ["morning", "afternoon"],
            "medium_frequency",
            priority=5
        )
        
        # Low frequency conditions
        self.router.add_condition(
            lambda state: state.get("device_type") == "mobile",
            "low_frequency",
            priority=1
        )

# Usage
def create_efficient_graph() -> StateGraph:
    """Create graph with efficient conditional evaluation"""
    efficient_graph = EfficientGraph()
    return efficient_graph.graph
```

#### 4.1.2 Caching Conditional Results

```python
class CachedConditionRouter:
    def __init__(self, cache_size: int = 1000):
        self.cache_size = cache_size
        self.condition_cache = {}
        self.cache_order = []
        self.router = EfficientConditionRouter()
    
    def route(self, state: Dict) -> str:
        """Route using cached conditions"""
        # Create cache key from state
        cache_key = self.create_cache_key(state)
        
        # Check cache first
        if cache_key in self.condition_cache:
            return self.condition_cache[cache_key]
        
        # Evaluate conditions
        result = self.router.route(state)
        
        # Cache result
        self.condition_cache[cache_key] = result
        self.cache_order.append(cache_key)
        
        # Maintain cache size
        if len(self.cache_order) > self.cache_size:
            oldest_key = self.cache_order.pop(0)
            del self.condition_cache[oldest_key]
        
        return result
    
    def create_cache_key(self, state: Dict) -> str:
        """Create cache key from state"""
        # Use relevant fields for cache key
        relevant_fields = ["user_type", "priority", "time_of_day", "device_type"]
        key_parts = []
        
        for field in relevant_fields:
            if field in state:
                key_parts.append(f"{field}:{state[field]}")
        
        return ";".join(key_parts)

class CachedGraph:
    def __init__(self):
        self.router = CachedConditionRouter(cache_size=500)
        self.configure_conditions()
        self.graph = StateGraph(CachedState)
        
        # Add all possible nodes
        self.graph.add_node("router", self.router.route)
        self.graph.add_node("high_frequency", high_frequency_node)
        self.graph.add_node("medium_frequency", medium_frequency_node)
        self.graph.add_edge("low_frequency", low_frequency_node)
        self.graph.add_node("default", default_node)
        self.graph.add_node("end", end_node)
        
        self.graph.set_entry_point("router")
        self.graph.add_dynamic_edge("router", self.router.route)
        
        # Add static edges for terminal nodes
        self.graph.add_edge("high_frequency", "end")
        self.graph.add_edge("medium_frequency", "end")
        self.graph.add_edge("low_frequency", "end")
        self.graph.add_edge("default", "end")
        self.graph.add_edge("end", END)
    
    def configure_conditions(self) -> None:
        """Configure conditions with caching"""
        # High frequency conditions
        self.router.router.add_condition(
            lambda state: state.get("user_type") == "admin",
            "high_frequency",
            priority=10
        )
        
        self.router.router.add_condition(
            lambda state: state.get("priority", 0) >= 3,
            "high_frequency",
            priority=10
        )
        
        # Medium frequency conditions
        self.router.router.add_condition(
            lambda state: state.get("time_of_day") in ["morning", "afternoon"],
            "medium_frequency",
            priority=5
        )

# Usage
def create_cached_graph() -> StateGraph:
    """Create graph with cached conditional evaluation"""
    cached_graph = CachedGraph()
    return cached_graph.graph
```

---

## Testing Conditional Branching

### 5.1 Unit Testing Conditional Logic

```python
def test_conditional_branching():
    """Test conditional branching logic"""
    # Test simple conditional branching
    state = {"input": "research paper", "confidence": 0.95}
    
    graph = create_conditional_graph()
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "high_confidence" in str(result)
    
    # Test multiple conditional edges
    state = {"input": "implement code", "confidence": 0.75, "user_type": "premium"}
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "medium_confidence" in str(result)
    assert "premium" in str(result)

def test_dynamic_routing():
    """Test dynamic routing functionality"""
    graph = create_dynamic_graph()
    
    # Test high confidence routing
    state = {"input": "urgent research", "confidence": 0.95}
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "high_confidence" in str(result)
    
    # Test admin routing
    state = {"input": "system configuration", "user_type": "admin"}
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "admin" in str(result)

def test_state_based_edges():
    """Test state-based edge configuration"""
    graph = create_state_based_graph()
    
    # Test high priority routing
    state = {"priority": 3, "user_type": "admin", "time_of_day": "morning"}
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "high_priority" in str(result)
    assert "admin" in str(result)
    assert "business" in str(result)

def test_nested_conditioning():
    """Test nested conditional logic"""
    graph = create_nested_condition_graph()
    
    # Test complex nested conditions
    state = {
        "input": "urgent admin research",
        "user_type": "admin", 
        "priority": 3,
        "time_of_day": "morning",
        "device_type": "desktop",
        "location": "office"
    }
    
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "admin_high_priority_business" in str(result)

def test_rule_based_routing():
    """Test rule-based routing system"""
    graph = create_rule_based_graph()
    
    # Test priority rule
    state = {"priority": 3, "input": "high priority task"}
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "high_priority" in str(result)
    
    # Test user type rule
    state = {"user_type": "admin", "input": "admin task"}
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "admin" in str(result)

def test_state_pattern_matching():
    """Test state pattern matching"""
    graph = create_state_pattern_graph()
    
    # Test contains pattern
    state = {"input": "This is a research paper about AI", "priority": 2}
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "research" in str(result)
    
    # Test equals pattern
    state = {"user_type": "admin", "input": "admin task"}
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "admin" in str(result)

def test_state_machine_branching():
    """Test state machine branching"""
    graph = create_state_machine_graph()
    
    # Test successful processing
    state = {"current_state": "initial", "event": "start", "data": {"task": "test"}}
    result = graph.compile().invoke(state)
    
    assert result["current_state"] == "processing"
    assert result.get("result") is not None
    
    # Test error handling
    state = {"current_state": "processing", "event": "error", "error": "Test error"}
    result = graph.compile().invoke(state)
    
    assert result["current_state"] == "error"
    assert "Test error" in str(result)

def test_hierarchical_branching():
    """Test hierarchical branching"""
    graph = create_hierarchical_graph()
    
    # Test multi-level routing
    state = {
        "data": {
            "category": "a",
            "type": "x",
            "subtype": "y"
        }
    }
    
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "level3_a1y" in str(result)

def test_context_aware_branching():
    """Test context-aware branching"""
    graph = create_context_aware_graph()
    
    # Test context pattern matching
    state = {
        "context": {"user_type": "admin", "priority": "high"},
        "history": []
    }
    
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "context_a" in str(result)
    
    # Test history pattern matching
    state = {
        "context": {"user_type": "regular"},
        "history": [{"action": "login", "success": True}]
    }
    
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "history_a" in str(result)

def test_efficient_branching():
    """Test efficient conditional evaluation"""
    graph = create_efficient_graph()
    
    # Test high frequency conditions first
    state = {"user_type": "admin", "priority": 3, "time_of_day": "morning"}
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "high_frequency" in str(result)
    
    # Test medium frequency conditions
    state = {"time_of_day": "afternoon", "input": "test input"}
    result = graph.compile().invoke(state)
    
    assert result["result"] is not None
    assert "medium_frequency" in str(result)

def test_cached_branching():
    """Test cached conditional evaluation"""
    graph = create_cached_graph()
    
    # First call - should compute
    state = {"user_type": "admin", "priority": 3}
    result1 = graph.compile().invoke(state)
    
    # Second call with same state - should use cache
    result2 = graph.compile().invoke(state)
    
    assert result1["result"] == result2["result"]
    assert "high_frequency" in str(result1)
    assert "high_frequency" in str(result2)
```

### 5.2 Integration Testing Conditional Flow

```python
def test_complete_conditional_flow():
    """Test complete conditional flow through graph"""
    # Create comprehensive graph with all conditional patterns
    graph = create_conditional_graph()
    
    # Test various input scenarios
    test_cases = [
        {
            "input": "urgent research paper",
            "confidence": 0.98,
            "user_type": "admin",
            "time_of_day": "morning",
            "expected": ["high_confidence", "admin", "business"]
        },
        {
            "input": "implement feature",
            "confidence": 0.75,
            "user_type": "premium",
            "time_of_day": "afternoon",
            "expected": ["medium_confidence", "premium", "business"]
        },
        {
            "input": "help with login",
            "confidence": 0.6,
            "user_type": "free",
            "time_of_day": "evening",
            "expected": ["low_confidence", "free", "personal"]
        },
        {
            "input": "exit application",
            "confidence": 0.9,
            "user_type": "any",
            "time_of_day": "any",
            "expected": ["end"]
        }
    ]
    
    for i, test_case in enumerate(test_cases):
        result = graph.compile().invoke(test_case)
        
        # Verify expected patterns in result
        result_str = str(result)
        for expected in test_case["expected"]:
            assert expected in result_str, f"Test case {i} failed: expected {expected} in result"

def test_performance_conditional_branching():
    """Test performance of conditional branching"""
    import time
    
    # Create graph
    graph = create_conditional_graph()
    compiled_graph = graph.compile()
    
    # Generate test cases
    test_cases = []
    for i in range(1000):
        test_cases.append({
            "input": f"test input {i}",
            "confidence": random.uniform(0, 1),
            "user_type": random.choice(["admin", "premium", "free"]),
            "time_of_day": random.choice(["morning", "afternoon", "evening", "night"])
        })
    
    # Test performance
    start_time = time.time()
    
    for test_case in test_cases:
        result = compiled_graph.invoke(test_case)
        assert result is not None
    
    elapsed_time = time.time() - start_time
    print(f"Conditional branching performance: {elapsed_time:.2f} seconds for 1000 operations")
    assert elapsed_time < 5.0  # Should complete in less than 5 seconds

def test_error_handling_in_conditional_branching():
    """Test error handling in conditional branching"""
    graph = create_conditional_graph()
    
    # Test error in condition function
    def error_condition(state):
        raise RuntimeError("Condition function error")
    
    # Modify graph to use error condition (in real testing, you'd mock this)
    # For demonstration, assume we can inject error condition
    
    # Test with error condition
    state = {"input": "test", "confidence": 0.5}
    
    try:
        result = graph.compile().invoke(state)
        assert False, "Should have raised error"
    except Exception as e:
        assert "Condition function error" in str(e)

def test_edge_cases_in_conditional_branching():
    """Test edge cases in conditional branching"""
    graph = create_conditional_graph()
    
    # Test empty input
    state = {"input": "", "confidence": 0.5}
    result = graph.compile().invoke(state)
    
    assert result is not None
    assert "low_confidence" in str(result) or "end" in str(result)
    
    # Test missing fields
    state = {"confidence": 0.8}  # No input field
    result = graph.compile().invoke(state)
    
    assert result is not None
    assert "low_confidence" in str(result) or "end" in str(result)
    
    # Test extreme values
    state = {"input": "a" * 10000, "confidence": 1.0, "user_type": "admin"}
    result = graph.compile().invoke(state)
    
    assert result is not None
    assert "high_confidence" in str(result)
    assert "admin" in str(result)
```

---

## Summary

This comprehensive guide covers:

| Topic | Key Points |
|-------|------------|
| **Core Concepts** | Basic conditional edges, simple branching patterns |
| **Advanced Patterns** | Dynamic routing, state-based edge creation, complex logic |
| **Multi-Level Branching** | Hierarchical branching, nested conditions, context-aware routing |
| **Performance** | Efficient evaluation, caching, optimization strategies |
| **Testing** | Unit testing, integration testing, edge case handling |

---

*Document Version: 1.0*
*Last Updated: January 2026*

---

## Next Steps

After implementing conditional branching, explore:
- [Parallel Execution Patterns](../parallel_execution.md)
- [State Compression Techniques](../state_compression.md)
- [Memory Management](../memory_management.md)
- [Performance Optimization](../performance.md)