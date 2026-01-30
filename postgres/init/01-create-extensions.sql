-- Enable pgvector extension for vector similarity search
-- This runs automatically when the PostgreSQL container is first created

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
