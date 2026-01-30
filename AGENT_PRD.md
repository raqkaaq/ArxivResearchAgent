# Agent Layer Product Requirements Document: Multiagent Orchestration for Arxiv Research Agent

## Overview
This PRD details the agent layer of the Arxiv Research Agent, focusing on multiagent orchestration via Orchestral AI. It includes the supervisor for routing, subgraphs for CLI and automator tasks, and specialized agents like BranchAgent for dynamic context branching. The layer emphasizes stateful, adaptive reasoning while separating concerns (e.g., no direct LLM calls in non-agent components).

The agent layer enables intelligent task delegation, with BranchAgent as the primary specialized type for exploring multiple approaches and consolidating results.

## Supervisor Agent
- **Role**: Top-level router that evaluates user input and delegates to appropriate subgraphs.
- **Functionality**: Parses input (e.g., "chat" triggers CLI, "automate" triggers automator); updates shared state.
- **Integration**: Orchestral AI node; uses Command for routing.

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
BranchAgent is an Orchestral AI node/agent that dynamically explores multiple approaches to solve a task (e.g., different RAG strategies or prompt variants), evaluates results via LLM, and merges the best outcome into the main conversation context. It is the only specialized agent type currently; others may be added later.

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
- **Non-Functional**: Max 3 branches to limit latency; LLM calls for eval; use Orchestral AI checkpointer for persistence, interrupts for human-in-loop, streaming for real-time responses.
- **Dependencies**: Orchestral AI (with checkpointer, interrupts, streaming), LLM integration.

## State Sharing & Communication
- **Shared State**: TypedDict with liked_embeddings (list of vectors), PostgreSQL client, Neo4j connection, SQLite connection, user_id.
- **Stateful Design**: Hybrid approach - stateful graphs with DB persistence for context-heavy tasks (CLI chat, Context Management).
- **Communication Mechanisms**:
  - Command-based routing via Orchestral AI Command for subgraph transitions
  - State mutations via SharedState updates in supervisor and nodes
  - Interrupts for human-in-loop interventions (e.g., confirm BranchAgent branches)
  - Streaming for real-time node outputs and progress updates
- **Persistence Layers**:
  - Orchestral AI checkpointer (MemorySaver) for in-session graph state recovery
  - PostgreSQL/Neo4j for long-term storage (load on startup for state restoration)
- **Edge Case Handling**:
  - Concurrent CLI/automator runs: Use threading locks or queue for thread safety
  - Session isolation: User-based session IDs to separate contexts

## Hybrid Agent State Management
```python
class HybridAgentState:
    """State management across PostgreSQL, Neo4j, and SQLite"""
    
    def __init__(self):
        self.postgres_client = None
        self.neo4j_connection = None
        self.sqlite_conn = None
        
        self.current_query = None
        self.postgres_results = []
        self.graph_results = []
        self.fused_results = []
        
    def update_graph_reference(self, paper_id, node_data):
        """Maintain graph references in Neo4j"""
        if self.neo4j_connection is None:
            self.neo4j_connection = get_neo4j_connection()
        self.neo4j_connection.execute_query(
            "MERGE (p:Paper {id: $id}) SET p += $data",
            id=paper_id, data=node_data
        )
```

### Multi-Database Supervisor Agent
```python
class HybridSupervisorAgent:
    """Supervisor agent coordinating hybrid operations"""
    
    def __init__(self, postgres_url, neo4j_uri, sqlite_path):
        self.state = HybridAgentState()
        self.postgres = create_postgres_connection(postgres_url)
        self.neo4j = Neo4jConnection(neo4j_uri)
        self.sqlite = sqlite3.connect(sqlite_path)
        self.query_router = HybridQueryRouter(self.postgres, self.neo4j)
        
    async def route_to_subgraph(self, state):
        """Route queries to appropriate subgraph"""
        query = state.get('current_query', '')
        routing = await self.query_router.analyze_and_route(query)
        
        if routing['subgraph'] == 'cli':
            return await self.route_to_cli_subgraph(state, routing)
        elif routing['subgraph'] == 'automator':
            return await self.route_to_automator_subgraph(state, routing)
        else:
            raise ValueError(f"Unknown subgraph: {routing['subgraph']}")
    
    async def route_to_cli_subgraph(self, state, routing):
        """Route to CLI with hybrid RAG capabilities"""
        self.state.current_query = routing['query']
        self.state.routing_strategy = routing['strategy']
        
        hybrid_results = await self.query_router.execute_hybrid_query(
            routing['query'], routing['strategy']
        )
        
        self.state.postgres_results = hybrid_results.get('postgres_results', [])
        self.state.graph_results = hybrid_results.get('graph_results', [])
        self.state.fused_results = hybrid_results.get('fused_results', [])
        
        return {
            'next': 'hybrid_rag_node',
            'state': self.state
        }
```

## Requirements & Roadmap
- **Functional**: Route accurately to hybrid storage; BranchAgent explores effectively; Neo4j graph consistency maintained.
- **Non-Functional**: Low latency (<3s hybrid queries); testable operations.
- **Roadmap**: Implement supervisor/subgraphs with hybrid coordination; add BranchAgent; test branching.

This PRD focuses on BranchAgent as the key specialized type. Reference PRD.md for overall integration.