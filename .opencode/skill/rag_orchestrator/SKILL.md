# RAG Orchestrator Skill

This skill encapsulates RAG nodes for retrieval-augmented generation, including vector search, knowledge graph traversal, and agentic grading/rewriting.

## Features
- Retrieve node with Chroma integration.
- Graph traversal (PageRank, centrality).
- HyDE for hypothetical embeddings.
- Grading and rewriting nodes.

## Usage
Load for RAG implementation. Provides pre-built nodes for retrieval pipelines.

## Implementation
- Draws from LangGraph RAG tutorials.
- Supports vector + graph hybrid retrieval.

## Code Examples
From LangGraph RAG how-tos:

```python
from langchain_chroma import Chroma
from langchain_core.prompts import PromptTemplate
from langgraph.graph import StateGraph

# Retrieve node
def retrieve(state):
    query = state["query"]
    retriever = Chroma(...).as_retriever()
    docs = retriever.invoke(query)
    return {"docs": docs}

# Grade node
def grade_documents(state):
    docs = state["docs"]
    # LLM grading logic
    return {"filtered_docs": [d for d in docs if score > 0.7]}

# Build graph
builder = StateGraph(RAGState)
builder.add_node("retrieve", retrieve)
builder.add_node("grade", grade_documents)
builder.add_conditional_edges("retrieve", grade_documents)
graph = builder.compile()
```