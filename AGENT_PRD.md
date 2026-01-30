# Agent Layer Product Requirements Document: Multiagent Orchestration for Arxiv Research Agent

## Overview
This PRD details the agent layer of the Arxiv Research Agent, focusing on multiagent orchestration via LangGraph. It includes the supervisor for routing, subgraphs for CLI and automator tasks, and specialized agents like BranchAgent for dynamic context branching. The layer emphasizes stateful, adaptive reasoning while separating concerns (e.g., no direct LLM calls in non-agent components).

The agent layer enables intelligent task delegation, with BranchAgent as the primary specialized type for exploring multiple approaches and consolidating results.

## Supervisor Agent
- **Role**: Top-level router that evaluates user input and delegates to appropriate subgraphs.
- **Functionality**: Parses input (e.g., "chat" triggers CLI, "automate" triggers automator); updates shared state.
- **Integration**: LangGraph node; uses Command for routing.

## Subgraph Agents
### CLI Subgraph
- **Nodes**: input_node (validate query), hybrid_rag_node (retrieve via hybrid PostgreSQL+Neo4j RAG), response_node (generate reply), like_node (update preferences).
- **Purpose**: Interactive chat for research and paper management.
- **State**: Extends SharedState with user_query, retrieved_papers.

### Automator Subgraph
- **Nodes**: pull_node (fetch Arxiv papers), embed_node (generate vectors), similarity_node (compare to liked), classify_node (importance score), hybrid_store_node (save to PostgreSQL + Neo4j), clean_node (prune).
- **Purpose**: Background ingestion and classification.
- **State**: Extends SharedState with recent_papers, classified_papers, graph_relationships.

## BranchAgent (Specialized Agent Type)
BranchAgent is the primary specialized agent type, enabling dynamic context branching for complex tasks.

### Overview
BranchAgent is a LangGraph node/agent that dynamically explores multiple approaches to solve a task (e.g., different RAG strategies or prompt variants), evaluates results via LLM, and merges the best outcome into the main conversation context. It is the only specialized agent type currently; others may be added later.

### Mechanism
- **Trigger**: Activated by supervisor or subgraphs for ambiguous/complex queries (e.g., heuristic on query length or entropy).
- **Exploration**: Spawns 2-3 parallel branches, each testing a variant (e.g., Path 1: Standard RAG; Path 2: Graph-enhanced; Path 3: Speculative).
- **Evaluation**: LLM scores each result (e.g., combine faithfulness and relevance scores).
- **Merging**: Selects best result; calls Context Management endpoints to merge into the context chain.
- **Integration**: Uses shared state; interfaces with Context Management for compression/merging.

### Architecture
```mermaid
graph TD
    A[Trigger BranchAgent] --> B[Spawn Branches]
    B --> C1[Branch 1: Approach 1]
    B --> C2[Branch 2: Approach 2]
    B --> C3[Branch 3: Approach 3]
    C1 --> D[Evaluate Results]
    C2 --> D
    C3 --> D
    D --> E[Merge Best to Context]
    E --> F[Update Shared State]
```

### Requirements
- **Functional**: Explore 2-3 approaches; evaluate/merge reliably.
- **Non-Functional**: Max 3 branches to limit latency; LLM calls for eval; use LangGraph checkpointer for persistence, interrupts for human-in-loop, streaming for real-time responses.
- **Dependencies**: LangGraph (with checkpointer, interrupts, streaming), LLM integration.

## State Sharing & Communication
- **Shared State**: TypedDict with liked_embeddings, cross_database_references, PostgreSQL connections, Neo4j sessions.
- **Communication**: Command-based routing; state mutations.
- **Persistence**: LangGraph checkpointer (MemorySaver) for graph state; DBs for long-term.
- **Advanced LangGraph Features**: Interrupts for user interventions (e.g., confirm branches); streaming for real-time node outputs; tool integration for external APIs (e.g., SDKs as tools).

## Cross-Database Agent Implementation
### Hybrid Agent State Management
```python
class HybridAgentState:
    """State management across PostgreSQL and Neo4j databases"""
    
    def __init__(self):
        # PostgreSQL connections and Neo4j sessions
        self.pg_pool = None
        self.neo4j_driver = None
        self.cross_references = {}
        
        # Agent state
        self.current_query = None
        self.pg_results = []
        self.neo4j_results = []
        self.fused_results = []
        
    def update_cross_references(self, pg_paper_id, neo4j_node_id):
        """Maintain cross-database references"""
        self.cross_references[pg_paper_id] = {
            'neo4j_node_id': neo4j_node_id,
            'last_sync': datetime.now()
        }

### Multi-Database Supervisor Agent
```python
class HybridSupervisorAgent:
    """Supervisor agent coordinating hybrid database operations"""
    
    def __init__(self, pg_pool, neo4j_driver):
        self.state = HybridAgentState()
        self.pg_pool = pg_pool
        self.neo4j_driver = neo4j_driver
        self.query_router = HybridQueryRouter(pg_pool, neo4j_driver)
        
    async def route_to_subgraph(self, state):
        """Route queries to appropriate subgraph with hybrid capabilities"""
        query = state.get('current_query', '')
        
        # Determine routing based on query complexity
        routing = await self.query_router.analyze_and_route(query)
        
        if routing['subgraph'] == 'cli':
            return await self.route_to_cli_subgraph(state, routing)
        elif routing['subgraph'] == 'automator':
            return await self.route_to_automator_subgraph(state, routing)
        else:
            raise ValueError(f"Unknown subgraph: {routing['subgraph']}")
    
    async def route_to_cli_subgraph(self, state, routing):
        """Route to CLI with hybrid RAG capabilities"""
        # Update state with routing information
        self.state.current_query = routing['query']
        self.state.routing_strategy = routing['strategy']
        
        # Execute hybrid query
        hybrid_results = await self.query_router.execute_hybrid_query(
            routing['query'], routing['strategy']
        )
        
        self.state.pg_results = hybrid_results.get('postgresql_results', [])
        self.state.neo4j_results = hybrid_results.get('neo4j_results', [])
        self.state.fused_results = hybrid_results.get('fused_results', [])
        
        # Return next node action
        return {
            'next': 'hybrid_rag_node',
            'state': self.state
        }
```

## Requirements & Roadmap
- **Functional**: Route accurately to hybrid databases; BranchAgent explores effectively; cross-database consistency maintained.
- **Non-Functional**: Low latency (<3s hybrid queries); testable cross-database operations.
- **Roadmap**: Implement supervisor/subgraphs with hybrid coordination; add BranchAgent; test branching; implement sync services.

This PRD focuses on BranchAgent as the key specialized type. Reference PRD.md for overall integration.