# Orchestral AI Skill

This skill provides documentation and best practices for building agents with Orchestral AI, based on up-to-date design principles for multiagent orchestration.

## Documentation
Reference these docs when building Orchestral AI agents:
- [Architecture Overview](../../../../docs/orchestral_ai/architecture.md)
- [API Reference](../../../../docs/orchestral_ai/api.md)
- [Examples](../../../../docs/orchestral_ai/examples.md)
- [Context Management](../../../../docs/orchestral_ai/context.md)
- [Tools Guide](../../../../docs/orchestral_ai/tools.md)
- [Providers Guide](../../../../docs/orchestral_ai/providers.md)

## Loading the Skill

To use this skill, load it in your opencode session as needed for agent development with Orchestral AI.

## Up-to-Date Orchestral AI Design Principles

Follow these steps to build robust, stateful agents with Orchestral AI:

### Step 1: Map Workflow to Discrete Nodes

Identify distinct steps in your process. Each step becomes a node. Sketch connections between nodes.

Node types:
- **AgentNodes**: For understanding, analyzing, generating text, or reasoning with LLMs.
- **Data Nodes**: For retrieving information from external sources (Arxiv, PostgreSQL, Neo4j).
- **Action Nodes**: For performing external actions (downloads, storage).
- **User Input Nodes**: For human intervention.

### Step 2: Identify What Each Node Needs

For each node, determine required context and outcomes:
- Static context (prompts, guidelines).
- Dynamic context (from shared state).
- Desired outcome (e.g., classifications, responses).

### Step 3: Design Your State

State is shared memory for all nodes using TypedDict. Store raw data only, not formatted prompts.

What belongs in state:
- Data that persists across steps (liked_embeddings, query history).
- Database connections (PostgreSQL client, Neo4j connection).
- Avoid derivable data; compute on-demand.

Keep state raw: Format prompts inside nodes when needed.

Example state structure:
```python
from typing import TypedDict

class AgentState(TypedDict):
    raw_data: str
    classification: dict | None
    results: list | None
    liked_embeddings: list | None
    postgres_client: object | None
    neo4j_connection: object | None
```

### Step 4: Build Your Nodes

Implement each step as a function taking state and returning dict updates.

Handle errors appropriately:
- Transient errors (e.g., network): Retry with policy.
- LLM-recoverable errors: Store error and loop back.
- Unexpected errors: Let them bubble up.

Example node:
```python
from typing import TypedDict, Literal

def classify_node(state: AgentState):
    # Do work, handle errors
    result = classify_paper(state["raw_data"])
    return {"classification": result, "next": "next_node"}
```

### Step 5: Wire It Together

Connect nodes in a sequence. Nodes handle routing via state updates.

Example:
```python
from orchestral import Agent
from orchestral.llm import Claude

agent = Agent(
    llm=Claude(),
    system_prompt="You are a research agent..."
)
```

### Step 6: Define Subgraphs

For complex workflows, define subgraphs (CLI subgraph, Automator subgraph) that the supervisor routes to.

CLI Subgraph nodes:
- input_node: Validate and parse user query
- hybrid_rag_node: Retrieve via PostgreSQL + Neo4j
- response_node: Generate reply
- like_node: Update user preferences

Automator Subgraph nodes:
- pull_node: Fetch Arxiv papers
- embed_node: Generate vectors
- similarity_node: Compare to liked embeddings
- classify_node: Importance scoring
- hybrid_store_node: Save to PostgreSQL + Neo4j
- clean_node: Prune old data

### Key Insights

- Break into discrete steps for resilience and observability.
- State stores raw data; nodes format as needed.
- Nodes are functions returning updates and routing decisions.
- Errors are part of the flow: retries, loops.
- Human input is supported via approval hooks.
- Use BranchAgent for complex queries requiring multiple approaches.

### Advanced Considerations

- Node granularity: Smaller nodes for more checkpoints and isolation.
- Performance: Use streaming for real-time feedback.
- Coordinate with PostgreSQL and Neo4j for hybrid storage.
- Reference docs/orchestral_ai for detailed patterns.

Use these principles for building complex, stateful multiagent systems with Orchestral AI.