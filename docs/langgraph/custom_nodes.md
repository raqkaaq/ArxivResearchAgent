# LangGraph Custom Node Creation Patterns

## Overview

This guide covers comprehensive patterns for creating custom nodes in LangGraph, including advanced node types, tool integration, state management, and best practices for building reusable, maintainable node components.

---

## Basic Custom Node Patterns

### 1.1 Function-Based Custom Nodes

Create custom nodes using Python functions with proper type hints and state management.

#### 1.1.1 Simple Custom Node

```python
from typing import TypedDict, Any, Optional
from langgraph.graph import StateGraph, END

class CustomState(TypedDict):
    input: str
    processed: str | None
    metadata: dict | None
    error: str | None


def custom_processing_node(state: CustomState) -> CustomState:
    """Custom node for processing input data"""
    try:
        # Process input
        processed = process_input(state["input"])
        
        return {
            "processed": processed,
            "metadata": {"node": "custom_processing", "processed_at": datetime.now().isoformat()},
            "error": None
        }
        
    except Exception as e:
        return {
            "processed": None,
            "metadata": {"node": "custom_processing", "error": str(e)},
            "error": str(e)
        }

# Create graph with custom node
app = StateGraph(CustomState)
app.add_node("custom_processing", custom_processing_node)
app.set_entry_point("custom_processing")
app.add_edge("custom_processing", END)
```

#### 1.1.2 Configurable Custom Node

```python
from typing import TypedDict, Callable, Any
from functools import partial

class ConfigurableState(TypedDict):
    input: str
    config: dict
    result: Any | None
    error: str | None


def configurable_node(state: ConfigurableState) -> ConfigurableState:
    """Node with configurable processing"""
    try:
        config = state.get("config", {})
        
        # Apply configuration to processing
        result = apply_configuration(state["input"], config)
        
        return {
            "result": result,
            "error": None
        }
        
    except Exception as e:
        return {
            "result": None,
            "error": str(e)
        }

# Create configured versions of the node
uppercase_node = partial(configurable_node, config={"transform": "uppercase"})
lowercase_node = partial(configurable_node, config={"transform": "lowercase"})
reverse_node = partial(configurable_node, config={"transform": "reverse"})

def create_custom_graph() -> StateGraph:
    """Create graph with configured custom nodes"""
    graph = StateGraph(ConfigurableState)
    
    graph.add_node("uppercase", uppercase_node)
    graph.add_node("lowercase", lowercase_node)
    graph.add_node("reverse", reverse_node)
    graph.add_node("final", final_node)
    
    graph.set_entry_point("uppercase")
    graph.add_edge("uppercase", "lowercase")
    graph.add_edge("lowercase", "reverse")
    graph.add_edge("reverse", "final")
    graph.add_edge("final", END)
    
    return graph
```

### 1.2 Class-Based Custom Nodes

Create custom nodes using Python classes for more complex state and behavior.

#### 1.2.1 Stateful Custom Node

```python
import uuid
from typing import TypedDict, Any, Optional
from datetime import datetime

class StatefulState(TypedDict):
    session_id: str
    user_input: str
    conversation_history: list
    current_intent: str | None
    processing_context: dict | None
    error: str | None

class StatefulNode:
    def __init__(self, node_id: str, config: dict = None):
        self.node_id = node_id
        self.config = config or {}
        self.session_data = {}
    
    def initialize_session(self, state: StatefulState) -> StatefulState:
        """Initialize session for stateful processing"""
        session_id = str(uuid.uuid4())
        self.session_data[session_id] = {
            "created_at": datetime.now().isoformat(),
            "messages": [],
            "context": {}
        }
        
        return {
            "session_id": session_id,
            "conversation_history": [],
            "processing_context": {},
            "error": None
        }
    
    def process_message(self, state: StatefulState) -> StatefulState:
        """Process message with session context"""
        try:
            session_id = state["session_id"]
            
            # Get session data
            session = self.session_data.get(session_id, {})
            
            # Process message with context
            processed_message = self.process_with_context(
                state["user_input"],
                session.get("context", {})
            )
            
            # Update session
            session["messages"].append({
                "input": state["user_input"],
                "processed": processed_message,
                "timestamp": datetime.now().isoformat()
            })
            
            # Determine intent
            intent = self.detect_intent(processed_message)
            
            return {
                "conversation_history": session["messages"],
                "current_intent": intent,
                "processing_context": session["context"],
                "error": None
            }
            
        except Exception as e:
            return {
                "conversation_history": state.get("conversation_history", []),
                "current_intent": None,
                "processing_context": state.get("processing_context", {}),
                "error": str(e)
            }
    
    def process_with_context(self, message: str, context: dict) -> str:
        """Process message using context"""
        # Custom processing logic using context
        return f"Processed: {message} (Context: {context})"
    
    def detect_intent(self, message: str) -> str:
        """Detect intent from message"""
        if "weather" in message.lower():
            return "weather_query"
        elif "time" in message.lower():
            return "time_query"
        elif "help" in message.lower():
            return "help_request"
        return "general_query"

# Usage in graph
def stateful_node_wrapper(state: StatefulState) -> StatefulState:
    """Wrapper function for stateful node"""
    node = StatefulNode(node_id="stateful_node")
    
    if not state.get("session_id"):
        return node.initialize_session(state)
    
    return node.process_message(state)


def create_stateful_graph() -> StateGraph:
    """Create graph with stateful node"""
    graph = StateGraph(StatefulState)
    
    graph.add_node("stateful", stateful_node_wrapper)
    graph.add_node("respond", respond_node)
    graph.add_node("cleanup", cleanup_node)
    
    graph.set_entry_point("stateful")
    graph.add_edge("stateful", "respond")
    graph.add_edge("respond", "cleanup")
    graph.add_edge("cleanup", END)
    
    return graph
```

---

## Advanced Custom Node Patterns

### 2.1 Tool Integration Custom Nodes

Create custom nodes that integrate with external tools and APIs.

#### 2.1.1 API Integration Node

```python
import requests
from typing import TypedDict, Any, Optional
from datetime import datetime

class APIState(TypedDict):
    api_endpoint: str
    request_data: dict | None
    response_data: dict | None
    status: str | None
    error: str | None
    metadata: dict | None

class APINode:
    def __init__(self, base_url: str, timeout: int = 30, retries: int = 3):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.retries = retries
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": "LangGraph-Client/1.0"})
    
    def make_request(self, state: APIState) -> APIState:
        """Make HTTP request with retry logic"""
        try:
            endpoint = state.get("api_endpoint", "")
            url = f"{self.base_url}/{endpoint.lstrip('/')}"
            request_data = state.get("request_data")
            
            # Determine request method
            method = request_data.get("method", "GET") if request_data else "GET"
            
            # Prepare request
            headers = {"Content-Type": "application/json"}
            if "headers" in request_data:
                headers.update(request_data["headers"])
            
            # Make request with retries
            for attempt in range(self.retries):
                try:
                    if method == "GET":
                        response = self.session.get(
                            url,
                            params=request_data.get("params"),
                            headers=headers,
                            timeout=self.timeout
                        )
                    elif method == "POST":
                        response = self.session.post(
                            url,
                            json=request_data.get("data"),
                            headers=headers,
                            timeout=self.timeout
                        )
                    elif method == "PUT":
                        response = self.session.put(
                            url,
                            json=request_data.get("data"),
                            headers=headers,
                            timeout=self.timeout
                        )
                    elif method == "DELETE":
                        response = self.session.delete(
                            url,
                            headers=headers,
                            timeout=self.timeout
                        )
                    else:
                        raise ValueError(f"Unsupported method: {method}")
                    
                    # Check response status
                    response.raise_for_status()
                    
                    # Parse response
                    response_data = response.json() if response.text else {}
                    
                    return {
                        "response_data": response_data,
                        "status": f"success_{response.status_code}",
                        "error": None,
                        "metadata": {
                            "url": url,
                            "method": method,
                            "status_code": response.status_code,
                            "response_time": response.elapsed.total_seconds(),
                            "timestamp": datetime.now().isoformat()
                        }
                    }
                    
                except requests.exceptions.RequestException as e:
                    if attempt == self.retries - 1:
                        # Last attempt failed
                        return {
                            "response_data": None,
                            "status": "error",
                            "error": str(e),
                            "metadata": {
                                "url": url,
                                "method": method,
                                "attempt": attempt + 1,
                                "error": str(e),
                                "timestamp": datetime.now().isoformat()
                            }
                        }
                    
                    # Wait before retrying
                    time.sleep(2 ** attempt)
            
        except Exception as e:
            return {
                "response_data": None,
                "status": "error",
                "error": str(e),
                "metadata": {
                    "error": str(e),
                    "timestamp": datetime.now().isoformat()
                }
            }
    
    def process_api_response(self, state: APIState) -> APIState:
        """Process API response data"""
        try:
            response_data = state.get("response_data")
            
            if not response_data:
                return state  # No data to process
            
            # Custom processing logic
            processed_data = self.transform_response(response_data)
            
            return {
                "response_data": processed_data,
                "status": "processed",
                "error": None,
                "metadata": {
                    "processing_time": datetime.now().isoformat(),
                    "processing_method": "transform_response"
                }
            }
            
        except Exception as e:
            return {
                "response_data": state.get("response_data"),
                "status": "processing_error",
                "error": str(e),
                "metadata": {
                    "error": str(e),
                    "timestamp": datetime.now().isoformat()
                }
            }
    
    def transform_response(self, response_data: dict) -> dict:
        """Transform API response to desired format"""
        # Custom transformation logic
        transformed = {}
        
        # Example: Flatten nested structure
        for key, value in response_data.items():
            if isinstance(value, dict):
                for sub_key, sub_value in value.items():
                    transformed[f"{key}_{sub_key}"] = sub_value
            else:
                transformed[key] = value
        
        return transformed

# Usage in graph
def api_node_wrapper(state: APIState) -> APIState:
    """Wrapper function for API node"""
    node = APINode(base_url="https://api.example.com", timeout=10, retries=3)
    
    # Make request
    state = node.make_request(state)
    
    # Process response if successful
    if state.get("status") == "success_200":
        state = node.process_api_response(state)
    
    return state


def create_api_graph() -> StateGraph:
    """Create graph with API integration node"""
    graph = StateGraph(APIState)
    
    graph.add_node("api_request", api_node_wrapper)
    graph.add_node("process_response", process_response_node)
    graph.add_node("store_data", store_data_node)
    graph.add_node("final", final_node)
    
    graph.set_entry_point("api_request")
    graph.add_edge("api_request", "process_response")
    graph.add_edge("process_response", "store_data")
    graph.add_edge("store_data", "final")
    graph.add_edge("final", END)
    
    return graph
```

#### 2.1.2 Database Integration Node

```python
import psycopg2
from psycopg2 import sql
from typing import TypedDict, Any, Optional
from datetime import datetime
import logging

class DatabaseState(TypedDict):
    query: str | None
    query_type: str | None  # "SELECT", "INSERT", "UPDATE", "DELETE"
    parameters: list | None
    result: Any | None
    row_count: int | None
    error: str | None
    transaction_id: str | None
    metadata: dict | None

class DatabaseNode:
    def __init__(self, connection_string: str, pool_size: int = 5):
        self.connection_string = connection_string
        self.pool_size = pool_size
        self.connections = []
        self.logger = logging.getLogger(__name__)
        
        # Initialize connection pool
        self.init_connection_pool()
    
    def init_connection_pool(self) -> None:
        """Initialize connection pool"""
        for _ in range(self.pool_size):
            conn = psycopg2.connect(self.connection_string)
            conn.autocommit = False
            self.connections.append(conn)
    
    def get_connection(self) -> Any:
        """Get connection from pool"""
        if self.connections:
            return self.connections.pop(0)
        # If pool is empty, create new connection
        return psycopg2.connect(self.connection_string)
    
    def return_connection(self, conn: Any) -> None:
        """Return connection to pool"""
        self.connections.append(conn)
    
    def execute_query(self, state: DatabaseState) -> DatabaseState:
        """Execute database query with transaction support"""
        conn = None
        cursor = None
        
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            
            query = state.get("query")
            query_type = state.get("query_type", "SELECT").upper()
            parameters = state.get("parameters")
            
            if not query:
                raise ValueError("Query is required")
            
            # Start transaction if needed
            transaction_id = str(uuid.uuid4())
            
            # Execute query
            if query_type == "SELECT":
                cursor.execute(query, parameters)
                result = cursor.fetchall()
                row_count = cursor.rowcount
                
            elif query_type in ["INSERT", "UPDATE", "DELETE"]:
                cursor.execute(query, parameters)
                conn.commit()
                result = None
                row_count = cursor.rowcount
                
            else:
                raise ValueError(f"Unsupported query type: {query_type}")
            
            # Return connection to pool
            self.return_connection(conn)
            conn = None  # Prevent double return
            
            return {
                "result": result,
                "row_count": row_count,
                "error": None,
                "transaction_id": transaction_id,
                "metadata": {
                    "query_type": query_type,
                    "executed_at": datetime.now().isoformat(),
                    "rows_affected": row_count,
                    "transaction_id": transaction_id
                }
            }
            
        except Exception as e:
            # Rollback on error
            if conn:
                conn.rollback()
                self.return_connection(conn)
            
            return {
                "result": None,
                "row_count": None,
                "error": str(e),
                "transaction_id": None,
                "metadata": {
                    "error": str(e),
                    "timestamp": datetime.now().isoformat()
                }
            }
        finally:
            if cursor:
                cursor.close()
            if conn and conn not in self.connections:
                conn.close()
    
    def process_results(self, state: DatabaseState) -> DatabaseState:
        """Process query results"""
        try:
            result = state.get("result")
            
            if result is None:
                return state  # No results to process
            
            # Custom processing logic
            processed_results = self.transform_results(result, state.get("query_type"))
            
            return {
                "result": processed_results,
                "row_count": state.get("row_count"),
                "error": None,
                "transaction_id": state.get("transaction_id"),
                "metadata": {
                    "processing_time": datetime.now().isoformat(),
                    "processed_results": True,
                    "original_row_count": state.get("row_count"),
                    "processed_row_count": len(processed_results) if isinstance(processed_results, list) else 1
                }
            }
            
        except Exception as e:
            return {
                "result": state.get("result"),
                "row_count": state.get("row_count"),
                "error": str(e),
                "transaction_id": state.get("transaction_id"),
                "metadata": {
                    "error": str(e),
                    "timestamp": datetime.now().isoformat()
                }
            }
    
    def transform_results(self, results: Any, query_type: str) -> Any:
        """Transform database results"""
        if query_type == "SELECT":
            # Convert tuples to dictionaries
            if isinstance(results, list) and results and isinstance(results[0], tuple):
                # Get column names
                column_names = [desc[0] for desc in cursor.description]
                return [dict(zip(column_names, row)) for row in results]
        
        return results

# Usage in graph
def database_node_wrapper(state: DatabaseState) -> DatabaseState:
    """Wrapper function for database node"""
    # Configure database connection
    connection_string = "postgresql://user:password@localhost:5432/mydatabase"
    node = DatabaseNode(connection_string, pool_size=10)
    
    # Execute query
    state = node.execute_query(state)
    
    # Process results if successful
    if not state.get("error"):
        state = node.process_results(state)
    
    return state


def create_database_graph() -> StateGraph:
    """Create graph with database integration node"""
    graph = StateGraph(DatabaseState)
    
    graph.add_node("database_query", database_node_wrapper)
    graph.add_node("process_results", process_database_results_node)
    graph.add_node("store_cache", store_in_cache_node)
    graph.add_node("final", final_node)
    
    graph.set_entry_point("database_query")
    graph.add_edge("database_query", "process_results")
    graph.add_edge("process_results", "store_cache")
    graph.add_edge("store_cache", "final")
    graph.add_edge("final", END)
    
    return graph
```

---

## Advanced Custom Node Patterns

### 3.1 Multi-Modal Custom Nodes

Create nodes that handle multiple types of inputs and outputs.

#### 3.1.1 Text and Image Processing Node

```python
from typing import TypedDict, Any, Optional, Union
from PIL import Image
import io
import base64
from datetime import datetime

class MultiModalState(TypedDict):
    text_input: str | None
    image_input: str | None  # Base64 encoded image
    audio_input: str | None  # Base64 encoded audio
    processed_text: str | None
    processed_image: str | None  # Base64 encoded processed image
    processed_audio: str | None  # Base64 encoded processed audio
    analysis_results: dict | None
    error: str | None
    metadata: dict | None

class MultiModalNode:
    def __init__(self, config: dict = None):
        self.config = config or {}
        self.logger = logging.getLogger(__name__)
    
    def process_text(self, text: str) -> str:
        """Process text input"""
        try:
            # Example: Text analysis and transformation
            words = text.split()
            word_count = len(words)
            
            # Simple analysis
            analysis = {
                "word_count": word_count,
                "character_count": len(text),
                "has_numbers": any(char.isdigit() for char in text),
                "has_special_chars": any(not char.isalnum() for char in text)
            }
            
            # Transform text (example: capitalize)
            processed_text = text.upper()
            
            return processed_text, analysis
            
        except Exception as e:
            raise RuntimeError(f"Text processing failed: {e}")
    
    def process_image(self, image_base64: str) -> tuple[str, dict]:
        """Process image input"""
        try:
            # Decode base64 image
            image_data = base64.b64decode(image_base64)
            image = Image.open(io.BytesIO(image_data))
            
            # Image analysis
            width, height = image.size
            image_format = image.format
            image_mode = image.mode
            
            analysis = {
                "width": width,
                "height": height,
                "format": image_format,
                "mode": image_mode,
                "size_bytes": len(image_data)
            }
            
            # Image transformation (example: resize)
            new_size = (int(width * 0.5), int(height * 0.5))
            resized_image = image.resize(new_size)
            
            # Encode processed image
            buffered = io.BytesIO()
            resized_image.save(buffered, format="JPEG")
            processed_image_base64 = base64.b64encode(buffered.getvalue()).decode("utf-8")
            
            return processed_image_base64, analysis
            
        except Exception as e:
            raise RuntimeError(f"Image processing failed: {e}")
    
    def process_audio(self, audio_base64: str) -> tuple[str, dict]:
        """Process audio input"""
        try:
            # Decode base64 audio
            audio_data = base64.b64decode(audio_base64)
            audio_length = len(audio_data)
            
            # Audio analysis (simplified)
            analysis = {
                "length_bytes": audio_length,
                "duration_estimate": audio_length / 16000,  # Assuming 16kHz sample rate
                "has_audio": audio_length > 0
            }
            
            # Audio transformation (example: simple processing)
            # Note: Real audio processing would require audio libraries
            processed_audio = audio_data  # Identity transformation for example
            processed_audio_base64 = base64.b64encode(processed_audio).decode("utf-8")
            
            return processed_audio_base64, analysis
            
        except Exception as e:
            raise RuntimeError(f"Audio processing failed: {e}")
    
    def process_multimodal(self, state: MultiModalState) -> MultiModalState:
        """Process multimodal input"""
        results = {}
        analysis = {}
        
        # Process text input
        if state.get("text_input"):
            try:
                processed_text, text_analysis = self.process_text(state["text_input"])
                results["processed_text"] = processed_text
                analysis["text"] = text_analysis
            except Exception as e:
                results["text_error"] = str(e)
        
        # Process image input
        if state.get("image_input"):
            try:
                processed_image, image_analysis = self.process_image(state["image_input"])
                results["processed_image"] = processed_image
                analysis["image"] = image_analysis
            except Exception as e:
                results["image_error"] = str(e)
        
        # Process audio input
        if state.get("audio_input"):
            try:
                processed_audio, audio_analysis = self.process_audio(state["audio_input"])
                results["processed_audio"] = processed_audio
                analysis["audio"] = audio_analysis
            except Exception as e:
                results["audio_error"] = str(e)
        
        # Combine results
        processed_state = {"analysis_results": analysis}
        
        for key, value in results.items():
            if key.endswith("_error"):
                processed_state[key] = value
            else:
                processed_state[key] = value
        
        # Add metadata
        processed_state["metadata"] = {
            "processed_at": datetime.now().isoformat(),
            "input_types": [],
            "successful_processing": 0,
            "failed_processing": 0
        }
        
        for input_type in ["text", "image", "audio"]:
            if state.get(f"{input_type}_input"):
                processed_state["metadata"]["input_types"].append(input_type)
            
            if f"{input_type}_error" not in results:
                processed_state["metadata"]["successful_processing"] += 1
            else:
                processed_state["metadata"]["failed_processing"] += 1
        
        # Check for any errors
        if any(key.endswith("_error") for key in results):
            error_messages = [v for k, v in results.items() if k.endswith("_error")]
            processed_state["error"] = "; ".join(error_messages)
        
        return processed_state

# Usage in graph
def multimodal_node_wrapper(state: MultiModalState) -> MultiModalState:
    """Wrapper function for multimodal node"""
    node = MultiModalNode(config={})
    
    return node.process_multimodal(state)


def create_multimodal_graph() -> StateGraph:
    """Create graph with multimodal processing node"""
    graph = StateGraph(MultiModalState)
    
    graph.add_node("multimodal_processing", multimodal_node_wrapper)
    graph.add_node("analyze_results", analyze_multimodal_results_node)
    graph.add_node("store_results", store_multimodal_results_node)
    graph.add_node("final", final_node)
    
    graph.set_entry_point("multimodal_processing")
    graph.add_edge("multimodal_processing", "analyze_results")
    graph.add_edge("analyze_results", "store_results")
    graph.add_edge("store_results", "final")
    graph.add_edge("final", END)
    
    return graph
```

#### 3.1.2 Document Processing Node

```python
import PyPDF2
import textract
from typing import TypedDict, Any, Optional, List
import docx
import os
from datetime import datetime

class DocumentState(TypedDict):
    document_path: str | None
    document_type: str | None  # "pdf", "docx", "txt", "pptx"
    extracted_text: str | None
    metadata: dict | None
    pages: int | None
    word_count: int | None
    error: str | None
    processing_time: float | None

class DocumentNode:
    def __init__(self, config: dict = None):
        self.config = config or {}
        self.supported_types = {"pdf", "docx", "txt", "pptx"}
        self.logger = logging.getLogger(__name__)
    
    def detect_document_type(self, file_path: str) -> str | None:
        """Detect document type from file extension"""
        _, ext = os.path.splitext(file_path)
        ext = ext.lower().lstrip(".")
        
        if ext in self.supported_types:
            return ext
        
        # Try to detect from content for unknown extensions
        if ext not in self.supported_types:
            try:
                with open(file_path, "rb") as f:
                    header = f.read(4)
                    
                    if header.startswith(b"%PDF"):
                        return "pdf"
                    elif header.startswith(b"PK"):
                        return "docx"  # ZIP-based format
                    # Add more detection logic as needed
                    
            except Exception:
                pass
        
        return None
    
    def extract_text_from_pdf(self, file_path: str) -> tuple[str, dict]:
        """Extract text from PDF document"""
        try:
            start_time = time.time()
            
            with open(file_path, "rb") as file:
                reader = PyPDF2.PdfReader(file)
                text = ""
                
                for page_num in range(len(reader.pages)):
                    page = reader.pages[page_num]
                    text += page.extract_text() + "\n"
                
                processing_time = time.time() - start_time
                
                return text, {
                    "pages": len(reader.pages),
                    "processing_time": processing_time,
                    "extracted_at": datetime.now().isoformat()
                }
                
        except Exception as e:
            raise RuntimeError(f"PDF text extraction failed: {e}")
    
    def extract_text_from_docx(self, file_path: str) -> tuple[str, dict]:
        """Extract text from DOCX document"""
        try:
            start_time = time.time()
            
            doc = docx.Document(file_path)
            text = ""
            
            for para in doc.paragraphs:
                text += para.text + "\n"
            
            # Extract from tables
            for table in doc.tables:
                for row in table.rows:
                    for cell in row.cells:
                        text += cell.text + "\t"
                    text += "\n"
            
            processing_time = time.time() - start_time
            
            return text, {
                "pages": len(doc.sections),
                "tables": len(doc.tables),
                "processing_time": processing_time,
                "extracted_at": datetime.now().isoformat()
            }
            
        except Exception as e:
            raise RuntimeError(f"DOCX text extraction failed: {e}")
    
    def extract_text_from_txt(self, file_path: str) -> tuple[str, dict]:
        """Extract text from TXT document"""
        try:
            start_time = time.time()
            
            with open(file_path, "r", encoding="utf-8") as file:
                text = file.read()
            
            processing_time = time.time() - start_time
            
            return text, {
                "processing_time": processing_time,
                "extracted_at": datetime.now().isoformat()
            }
            
        except Exception as e:
            raise RuntimeError(f"TXT text extraction failed: {e}")
    
    def extract_text_from_unknown(self, file_path: str) -> tuple[str, dict]:
        """Extract text from unknown document type using textract"""
        try:
            start_time = time.time()
            
            text = textract.process(file_path, encoding="utf-8").decode("utf-8")
            processing_time = time.time() - start_time
            
            return text, {
                "processing_time": processing_time,
                "extracted_at": datetime.now().isoformat(),
                "method": "textract"
            }
            
        except Exception as e:
            raise RuntimeError(f"Unknown document text extraction failed: {e}")
    
    def process_document(self, state: DocumentState) -> DocumentState:
        """Process document file"""
        try:
            file_path = state.get("document_path")
            
            if not file_path or not os.path.exists(file_path):
                raise ValueError("Document path is required and must exist")
            
            # Detect document type
            doc_type = self.detect_document_type(file_path)
            if not doc_type:
                raise ValueError(f"Unsupported document type for file: {file_path}")
            
            # Extract text based on document type
            if doc_type == "pdf":
                text, metadata = self.extract_text_from_pdf(file_path)
            elif doc_type == "docx":
                text, metadata = self.extract_text_from_docx(file_path)
            elif doc_type == "txt":
                text, metadata = self.extract_text_from_txt(file_path)
            else:
                text, metadata = self.extract_text_from_unknown(file_path)
            
            # Calculate word count
            word_count = len(text.split()) if text else 0
            
            return {
                "extracted_text": text,
                "document_type": doc_type,
                "metadata": {
                    "pages": metadata.get("pages"),
                    "word_count": word_count,
                    "processing_time": metadata.get("processing_time"),
                    "extracted_at": metadata.get("extracted_at"),
                    "method": metadata.get("method", doc_type)
                },
                "pages": metadata.get("pages"),
                "word_count": word_count,
                "error": None
            }
            
        except Exception as e:
            return {
                "extracted_text": None,
                "document_type": None,
                "metadata": None,
                "pages": None,
                "word_count": None,
                "error": str(e),
                "processing_time": None
            }

# Usage in graph
def document_node_wrapper(state: DocumentState) -> DocumentState:
    """Wrapper function for document processing node"""
    node = DocumentNode(config={})
    
    return node.process_document(state)


def create_document_graph() -> StateGraph:
    """Create graph with document processing node"""
    graph = StateGraph(DocumentState)
    
    graph.add_node("document_processing", document_node_wrapper)
    graph.add_node("analyze_text", analyze_extracted_text_node)
    graph.add_node("store_metadata", store_document_metadata_node)
    graph.add_node("final", final_node)
    
    graph.set_entry_point("document_processing")
    graph.add_edge("document_processing", "analyze_text")
    graph.add_edge("analyze_text", "store_metadata")
    graph.add_edge("store_metadata", "final")
    graph.add_edge("final", END)
    
    return graph
```

---

## Advanced Custom Node Patterns

### 4.1 Error Handling and Recovery Custom Nodes

Create nodes that specialize in error handling and recovery.

#### 4.1.1 Circuit Breaker Node

```python
import time
from typing import TypedDict, Any, Optional
from datetime import datetime

class CircuitBreakerState(TypedDict):
    operation: str
    failure_count: int
    last_failure_time: str | None
    state: str  # "CLOSED", "OPEN", "HALF_OPEN"
    recovery_timeout: float
    failure_threshold: int
    result: Any | None
    error: str | None
    metadata: dict | None

class CircuitBreakerNode:
    def __init__(self, failure_threshold: int = 5, recovery_timeout: float = 60.0):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.failure_count = 0
        self.state = "CLOSED"
        self.last_failure_time = None
    
    def execute_with_circuit_breaker(self, operation: Callable, *args, **kwargs) -> CircuitBreakerState:
        """Execute operation with circuit breaker protection"""
        current_time = time.time()
        
        # Check circuit state
        if self.state == "OPEN":
            # Check if recovery timeout has passed
            if self.last_failure_time and (current_time - self.last_failure_time) > self.recovery_timeout:
                self.state = "HALF_OPEN"
            else:
                # Circuit is open, fail fast
                return {
                    "operation": operation.__name__,
                    "failure_count": self.failure_count,
                    "last_failure_time": self.last_failure_time,
                    "state": "OPEN",
                    "recovery_timeout": self.recovery_timeout,
                    "failure_threshold": self.failure_threshold,
                    "result": None,
                    "error": "Circuit breaker is OPEN",
                    "metadata": {
                        "circuit_state": "OPEN",
                        "timestamp": datetime.now().isoformat()
                    }
                }
        
        try:
            # Call the operation
            result = operation(*args, **kwargs)
            
            # If successful, reset failure count if in HALF_OPEN state
            if self.state == "HALF_OPEN":
                self.state = "CLOSED"
                self.failure_count = 0
            
            return {
                "operation": operation.__name__,
                "failure_count": self.failure_count,
                "last_failure_time": self.last_failure_time,
                "state": self.state,
                "recovery_timeout": self.recovery_timeout,
                "failure_threshold": self.failure_threshold,
                "result": result,
                "error": None,
                "metadata": {
                    "circuit_state": self.state,
                    "timestamp": datetime.now().isoformat(),
                    "success": True
                }
            }
            
        except Exception as e:
            error_message = str(e)
            self.failure_count += 1
            self.last_failure_time = current_time
            
            # Open circuit if failure threshold is reached
            if self.failure_count >= self.failure_threshold:
                self.state = "OPEN"
            
            return {
                "operation": operation.__name__,
                "failure_count": self.failure_count,
                "last_failure_time": self.last_failure_time,
                "state": self.state,
                "recovery_timeout": self.recovery_timeout,
                "failure_threshold": self.failure_threshold,
                "result": None,
                "error": error_message,
                "metadata": {
                    "circuit_state": self.state,
                    "failure_count": self.failure_count,
                    "error": error_message,
                    "timestamp": datetime.now().isoformat()
                }
            }

# Usage in graph
def circuit_breaker_node_wrapper(state: CircuitBreakerState) -> CircuitBreakerState:
    """Wrapper function for circuit breaker node"""
    node = CircuitBreakerNode(failure_threshold=3, recovery_timeout=30.0)
    
    # Example operation that might fail
    def example_operation():
        # Simulate operation that fails sometimes
        if random.random() < 0.7:  # 70% chance of failure
            raise ConnectionError("Simulated service failure")
        return "Operation succeeded"
    
    return node.execute_with_circuit_breaker(example_operation)


def create_circuit_breaker_graph() -> StateGraph:
    """Create graph with circuit breaker node"""
    graph = StateGraph(CircuitBreakerState)
    
    graph.add_node("circuit_breaker", circuit_breaker_node_wrapper)
    graph.add_node("fallback_operation", fallback_operation_node)
    graph.add_node("error_handler", error_handler_node)
    graph.add_node("final", final_node)
    
    graph.set_entry_point("circuit_breaker")
    
    # Conditional edges based on circuit breaker state
    graph.add_conditional_edges(
        "circuit_breaker",
        lambda state: state.get("state") == "OPEN",
        {"open": "fallback_operation", "closed": "final"}
    )
    
    graph.add_conditional_edges(
        "circuit_breaker",
        lambda state: state.get("error") is not None,
        {"error": "error_handler", "success": "final"}
    )
    
    graph.add_edge("fallback_operation", "final")
    graph.add_edge("error_handler", "final")
    graph.add_edge("final", END)
    
    return graph
```

#### 4.1.2 Retry Node with Backoff

```python
import time
import random
from typing import TypedDict, Any, Optional, Callable
from datetime import datetime

class RetryState(TypedDict):
    operation: str
    retry_count: int
    max_retries: int
    base_delay: float
    max_delay: float
    jitter: float
    result: Any | None
    error: str | None
    last_attempt_time: str | None
    total_delay: float | None
    metadata: dict | None

class RetryNode:
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
    
    def execute_with_retry(self, operation: Callable, *args, **kwargs) -> RetryState:
        """Execute operation with retry logic"""
        retry_count = 0
        total_delay = 0.0
        
        while retry_count <= self.max_retries:
            try:
                start_time = time.time()
                
                # Execute operation
                result = operation(*args, **kwargs)
                
                # Calculate total delay
                total_delay = time.time() - start_time if retry_count > 0 else 0
                
                return {
                    "operation": operation.__name__,
                    "retry_count": retry_count,
                    "max_retries": self.max_retries,
                    "base_delay": self.base_delay,
                    "max_delay": self.max_delay,
                    "jitter": self.jitter,
                    "result": result,
                    "error": None,
                    "last_attempt_time": datetime.now().isoformat(),
                    "total_delay": total_delay,
                    "metadata": {
                        "retry_count": retry_count,
                        "total_delay_seconds": total_delay,
                        "success": True,
                        "timestamp": datetime.now().isoformat()
                    }
                }
                
            except Exception as e:
                error_message = str(e)
                
                # Calculate delay for next retry
                delay = self.calculate_delay(retry_count)
                
                # Wait before retrying
                if retry_count < self.max_retries:
                    time.sleep(delay)
                    total_delay += delay
                
                retry_count += 1
                
                # If this is the last attempt, return error
                if retry_count > self.max_retries:
                    return {
                        "operation": operation.__name__,
                        "retry_count": retry_count,
                        "max_retries": self.max_retries,
                        "base_delay": self.base_delay,
                        "max_delay": self.max_delay,
                        "jitter": self.jitter,
                        "result": None,
                        "error": error_message,
                        "last_attempt_time": datetime.now().isoformat(),
                        "total_delay": total_delay,
                        "metadata": {
                            "retry_count": retry_count,
                            "total_delay_seconds": total_delay,
                            "max_retries_reached": True,
                            "error": error_message,
                            "timestamp": datetime.now().isoformat()
                        }
                    }

# Usage in graph
def retry_node_wrapper(state: RetryState) -> RetryState:
    """Wrapper function for retry node"""
    node = RetryNode(max_retries=5, base_delay=0.5, max_delay=10.0, jitter=0.2)
    
    # Example operation that might fail
    def example_operation():
        # Simulate operation that fails sometimes
        if random.random() < 0.6:  # 60% chance of failure
            raise ConnectionError("Simulated service failure")
        return "Operation succeeded after retry"
    
    return node.execute_with_retry(example_operation)


def create_retry_graph() -> StateGraph:
    """Create graph with retry node"""
    graph = StateGraph(RetryState)
    
    graph.add_node("retry_operation", retry_node_wrapper)
    graph.add_node("process_result", process_retry_result_node)
    graph.add_node("error_handler", retry_error_handler_node)
    graph.add_node("final", final_node)
    
    graph.set_entry_point("retry_operation")
    
    # Conditional edges based on retry outcome
    graph.add_conditional_edges(
        "retry_operation",
        lambda state: state.get("error") is None,
        {"success": "process_result", "error": "error_handler"}
    )
    
    graph.add_edge("process_result", "final")
    graph.add_edge("error_handler", "final")
    graph.add_edge("final", END)
    
    return graph
```

---

## Testing Custom Nodes

### 5.1 Unit Testing Custom Nodes

```python
def test_custom_processing_node():
    """Test custom processing node"""
    # Test successful processing
    state = {"input": "test input"}
    result = custom_processing_node(state)
    
    assert result["processed"] is not None
    assert result["error"] is None
    assert "node" in result["metadata"]
    assert "processed_at" in result["metadata"]

def test_configurable_node():
    """Test configurable node with different configurations"""
    # Test uppercase configuration
    state = {"input": "test", "config": {"transform": "uppercase"}}
    result = configurable_node(state)
    assert result["result"] == "TEST"
    
    # Test lowercase configuration
    state = {"input": "TEST", "config": {"transform": "lowercase"}}
    result = configurable_node(state)
    assert result["result"] == "test"
    
    # Test reverse configuration
    state = {"input": "test", "config": {"transform": "reverse"}}
    result = configurable_node(state)
    assert result["result"] == "tset"

def test_stateful_node():
    """Test stateful node with session management"""
    # Test session initialization
    initial_state = {"user_input": "hello"}
    node = StatefulNode(node_id="test_node")
    
    state = node.initialize_session(initial_state)
    assert state["session_id"] is not None
    assert state["conversation_history"] == []
    assert state["processing_context"] == {}
    assert state["error"] is None
    
    # Test message processing
    state = node.process_message({
        "session_id": state["session_id"],
        "user_input": "how are you?"
    })
    
    assert state["conversation_history"] is not None
    assert len(state["conversation_history"]) == 1
    assert state["current_intent"] in ["weather_query", "time_query", "help_request", "general_query"]
    assert state["processing_context"] is not None
    assert state["error"] is None

def test_api_node():
    """Test API integration node"""
    # Test successful API request
    state = {
        "api_endpoint": "test/endpoint",
        "request_data": {
            "method": "GET",
            "params": {"param": "value"}
        }
    }
    
    node = APINode(base_url="https://api.example.com", timeout=5, retries=2)
    result_state = node.make_request(state)
    
    assert result_state["status"] in ["success_200", "error"]
    assert "metadata" in result_state
    assert "timestamp" in result_state["metadata"]
    
    # Test error handling
    error_state = {
        "api_endpoint": "invalid/endpoint",
        "request_data": {"method": "GET"}
    }
    
    error_result_state = node.make_request(error_state)
    assert error_result_state["status"] == "error"
    assert error_result_state["error"] is not None

def test_database_node():
    """Test database integration node"""
    # Test database query
    state = {
        "query": "SELECT * FROM users WHERE id = %s",
        "query_type": "SELECT",
        "parameters": [1]
    }
    
    connection_string = "postgresql://user:password@localhost:5432/testdb"
    node = DatabaseNode(connection_string, pool_size=3)
    
    result_state = node.execute_query(state)
    
    assert result_state["result"] is not None or result_state["error"] is not None
    assert result_state["metadata"] is not None
    assert "executed_at" in result_state["metadata"]
    
    # Test error handling
    error_state = {
        "query": "INVALID SQL",
        "query_type": "SELECT"
    }
    
    error_result_state = node.execute_query(error_state)
    assert error_result_state["error"] is not None

def test_multimodal_node():
    """Test multimodal processing node"""
    # Test text processing
    node = MultiModalNode(config={})
    
    text_state = {"text_input": "This is a test message."}
    result_state = node.process_multimodal(text_state)
    
    assert result_state["analysis_results"] is not None
    assert "text" in result_state["analysis_results"]
    assert "word_count" in result_state["analysis_results"]["text"]
    assert "processed_text" in result_state
    
    # Test image processing (using base64 placeholder)
    # Note: Real testing would require actual image data
    image_state = {"image_input": "placeholder_base64_image_data"}
    result_state = node.process_multimodal(image_state)
    
    assert result_state["analysis_results"] is not None
    assert "image" in result_state["analysis_results"]
    assert "width" in result_state["analysis_results"]["image"]

def test_document_node():
    """Test document processing node"""
    # Test PDF processing
    node = DocumentNode(config={})
    
    pdf_state = {"document_path": "/path/to/test.pdf"}
    result_state = node.process_document(pdf_state)
    
    assert result_state["extracted_text"] is not None or result_state["error"] is not None
    assert result_state["metadata"] is not None
    assert "extracted_at" in result_state["metadata"]
    
    # Test error handling
    invalid_state = {"document_path": "/path/to/nonexistent.pdf"}
    error_state = node.process_document(invalid_state)
    
    assert error_state["error"] is not None
    assert error_state["extracted_text"] is None

def test_circuit_breaker_node():
    """Test circuit breaker node"""
    node = CircuitBreakerNode(failure_threshold=2, recovery_timeout=1.0)
    
    # Test successful operation
    def success_operation():
        return "Success"
    
    state = node.execute_with_circuit_breaker(success_operation)
    assert state["result"] == "Success"
    assert state["error"] is None
    assert state["state"] == "CLOSED"
    
    # Test operation that fails
    def failing_operation():
        raise ConnectionError("Service failure")
    
    # First failure
    state = node.execute_with_circuit_breaker(failing_operation)
    assert state["result"] is None
    assert state["error"] is not None
    assert state["state"] == "CLOSED"
    assert state["failure_count"] == 1
    
    # Second failure should open circuit
    state = node.execute_with_circuit_breaker(failing_operation)
    assert state["result"] is None
    assert state["error"] is not None
    assert state["state"] == "OPEN"
    assert state["failure_count"] == 2

def test_retry_node():
    """Test retry node with backoff"""
    node = RetryNode(max_retries=3, base_delay=0.1, max_delay=1.0, jitter=0.1)
    
    # Test operation that succeeds on second attempt
    def intermittent_operation():
        if intermittent_operation.attempt == 0:
            intermittent_operation.attempt += 1
            raise ConnectionError("First attempt failed")
        return "Success on second attempt"
    
    intermittent_operation.attempt = 0
    
    state = node.execute_with_retry(intermittent_operation)
    
    assert state["result"] == "Success on second attempt"
    assert state["error"] is None
    assert state["retry_count"] == 1  # One retry attempt
    assert state["total_delay"] > 0
    assert state["metadata"]["success"] is True
```

### 5.2 Integration Testing Custom Nodes

```python
def test_custom_node_integration():
    """Test custom node integration in complete graph"""
    # Create graph with custom nodes
    graph = create_custom_graph()
    
    # Test with valid input
    initial_state = {"input": "test input"}
    result = graph.compile().invoke(initial_state)
    
    assert result["processed"] is not None
    assert result["error"] is None
    assert "metadata" in result
    assert "processed_at" in result["metadata"]

def test_api_integration():
    """Test API integration node in graph"""
    graph = create_api_graph()
    
    # Test with valid API endpoint
    initial_state = {
        "api_endpoint": "test/success",
        "request_data": {
            "method": "GET",
            "params": {"test": "value"}
        }
    }
    
    result = graph.compile().invoke(initial_state)
    
    assert result["response_data"] is not None or result["error"] is not None
    assert result["status"] in ["success_200", "error"]
    assert result["metadata"] is not None

def test_database_integration():
    """Test database integration node in graph"""
    graph = create_database_graph()
    
    # Test with valid database query
    initial_state = {
        "query": "SELECT * FROM test_table WHERE id = %s",
        "query_type": "SELECT",
        "parameters": [1]
    }
    
    result = graph.compile().invoke(initial_state)
    
    assert result["result"] is not None or result["error"] is not None
    assert result["metadata"] is not None
    assert "executed_at" in result["metadata"]

def test_error_handling_integration():
    """Test error handling custom nodes in graph"""
    # Create graph with error handling nodes
    graph = create_circuit_breaker_graph()
    
    # Test circuit breaker behavior
    initial_state = {}
    
    # First few attempts should succeed or fail normally
    for i in range(3):
        result = graph.compile().invoke(initial_state)
        assert result["operation"] == "example_operation"
        assert result["state"] in ["CLOSED", "OPEN"]
    
    # After threshold, circuit should be open
    result = graph.compile().invoke(initial_state)
    assert result["state"] == "OPEN"
    assert result["error"] == "Circuit breaker is OPEN"

def test_performance_custom_nodes():
    """Test performance of custom nodes"""
    # Test custom processing node performance
    import time
    
    start_time = time.time()
    
    for i in range(1000):
        state = {"input": f"test input {i}"}
        result = custom_processing_node(state)
        assert result["processed"] is not None
    
    elapsed_time = time.time() - start_time
    print(f"Custom processing node: {elapsed_time:.2f} seconds for 1000 operations")
    
    # Test API node performance
    start_time = time.time()
    
    node = APINode(base_url="https://api.example.com", timeout=1, retries=1)
    
    for i in range(100):
        state = {
            "api_endpoint": "test/endpoint",
            "request_data": {"method": "GET"}
        }
        result_state = node.make_request(state)
        assert result_state["status"] in ["success_200", "error"]
    
    elapsed_time = time.time() - start_time
    print(f"API node: {elapsed_time:.2f} seconds for 100 operations")
```

---

## Best Practices

### 6.1 Custom Node Design Principles

#### 6.1.1 Single Responsibility

Each custom node should have a single, well-defined responsibility:

```python
# Good: Single responsibility

def text_processing_node(state: CustomState) -> CustomState:
    """Process text input only"""
    # Text processing logic
    return processed_state


def image_processing_node(state: CustomState) -> CustomState:
    """Process image input only"""
    # Image processing logic
    return processed_state

# Bad: Multiple responsibilities

def everything_node(state: CustomState) -> CustomState:
    """Process text, image, and audio (violates single responsibility)"""
    # Text processing
    # Image processing  
    # Audio processing
    return combined_state
```

#### 6.1.2 Idempotency

Custom nodes should be idempotent when possible:

```python
def idempotent_node(state: CustomState) -> CustomState:
    """Idempotent node that can be safely retried"""
    # Check if operation already completed
    if state.get("completed"):
        return state
    
    # Perform operation
    result = perform_operation(state["input"])
    
    return {
        "result": result,
        "completed": True,
        "timestamp": datetime.now().isoformat()
    }
```

#### 6.1.3 Error Isolation

Custom nodes should handle their own errors and not propagate exceptions:

```python
def error_isolated_node(state: CustomState) -> CustomState:
    """Node that handles its own errors"""
    try:
        result = perform_operation(state["input"])
        return {"result": result, "error": None}
    except Exception as e:
        return {"result": None, "error": str(e)}

# Bad: Propagating exceptions

def error_propagating_node(state: CustomState) -> CustomState:
    """Node that propagates exceptions (not recommended)"""
    result = perform_operation(state["input"])  # May raise exception
    return {"result": result, "error": None}
```

### 6.2 Custom Node Testing Principles

#### 6.2.1 Test Coverage

Ensure comprehensive test coverage for custom nodes:

```python
def test_custom_node_comprehensively():
    """Comprehensive testing of custom node"""
    # Test happy path
    happy_state = {"input": "valid input"}
    happy_result = custom_node(happy_state)
    assert happy_result["result"] is not None
    assert happy_result["error"] is None
    
    # Test error path
    error_state = {"input": "invalid input"}
    error_result = custom_node(error_state)
    assert error_result["result"] is None
    assert error_result["error"] is not None
    
    # Test edge cases
    edge_state = {"input": ""}  # Empty input
    edge_result = custom_node(edge_state)
    assert edge_result["result"] is not None or edge_result["error"] is not None
    
    # Test performance
    import time
    start_time = time.time()
    
    for i in range(100):
        test_state = {"input": f"test input {i}"}
        test_result = custom_node(test_state)
        assert test_result["result"] is not None
    
    elapsed_time = time.time() - start_time
    assert elapsed_time < 1.0  # Should complete in less than 1 second
```

#### 6.2.2 Mock External Dependencies

Test custom nodes with mocked external dependencies:

```python
def test_api_node_with_mock():
    """Test API node with mocked requests"""
    import unittest.mock as mock
    
    # Mock requests module
    with mock.patch('requests.Session.get') as mock_get:
        # Configure mock response
        mock_response = mock.Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"success": True}
        mock_response.text = json.dumps({"success": True})
        mock_get.return_value = mock_response
        
        # Test API node
        state = {
            "api_endpoint": "test/endpoint",
            "request_data": {"method": "GET"}
        }
        
        node = APINode(base_url="https://api.example.com", timeout=5, retries=1)
        result_state = node.make_request(state)
        
        assert result_state["status"] == "success_200"
        assert result_state["response_data"] == {"success": True}
        assert result_state["metadata"]["status_code"] == 200

def test_database_node_with_mock():
    """Test database node with mocked psycopg2"""
    import unittest.mock as mock
    
    # Mock psycopg2 module
    with mock.patch('psycopg2.connect') as mock_connect:
        # Configure mock connection and cursor
        mock_conn = mock.Mock()
        mock_cursor = mock.Mock()
        
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = [(1, "test")]
        mock_cursor.rowcount = 1
        mock_connect.return_value = mock_conn
        
        # Test database node
        state = {
            "query": "SELECT * FROM test_table WHERE id = %s",
            "query_type": "SELECT",
            "parameters": [1]
        }
        
        node = DatabaseNode(connection_string="postgresql://user:pass@localhost/db", pool_size=1)
        result_state = node.execute_query(state)
        
        assert result_state["result"] == [(1, "test")]
        assert result_state["row_count"] == 1
        assert result_state["error"] is None
```

### 6.3 Custom Node Performance Optimization

#### 6.3.1 Caching

Implement caching in custom nodes for performance:

```python
def caching_node(state: CustomState) -> CustomState:
    """Node with caching for performance"""
    cache_key = f"cache_{state["input"]}"
    
    if cache.get(cache_key):
        return {
            "result": cache[cache_key],
            "error": None,
            "metadata": {"cache_hit": True}
        }
    
    # Process input
    result = process_input(state["input"])
    
    # Cache result
    cache[cache_key] = result
    
    return {
        "result": result,
        "error": None,
        "metadata": {"cache_hit": False}
    }
```

#### 6.3.2 Connection Pooling

Use connection pooling for external resources:

```python
def connection_pooled_node(state: CustomState) -> CustomState:
    """Node with connection pooling"""
    # Get connection from pool
    conn = connection_pool.get_connection()
    
    try:
        # Use connection
        result = use_connection(conn, state["input"])
        return {"result": result, "error": None}
        
    except Exception as e:
        return {"result": None, "error": str(e)}
    finally:
        # Return connection to pool
        connection_pool.return_connection(conn)
```

---

## Summary

This comprehensive guide covers:

| Topic | Key Points |
|-------|------------|
| **Basic Patterns** | Function-based, class-based, configurable nodes |
| **Advanced Patterns** | Tool integration, database integration, multi-modal nodes |
| **Error Handling** | Circuit breakers, retry mechanisms, error isolation |
| **Testing** | Unit testing, integration testing, mocking strategies |
| **Best Practices** | Single responsibility, idempotency, performance optimization |

---

*Document Version: 1.0*
*Last Updated: January 2026*

---

## Next Steps

After implementing custom nodes, explore:
- [Performance Optimization](../performance.md)
- [Security Considerations](../security.md)
- [Testing Strategies](../testing.md)
- [Deployment Patterns](../deployment.md)