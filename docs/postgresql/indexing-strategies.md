# PostgreSQL Indexing Strategies Guide

## Overview
This comprehensive guide covers PostgreSQL indexing strategies, including when to use different index types, how to create effective indexes, and best practices for maintaining optimal database performance.

## Table of Contents
1. [Index Types](#index-types)
2. [Index Creation Strategies](#index-creation-strategies)
3. [Performance Optimization](#performance-optimization)
4. [Maintenance and Monitoring](#maintenance-and-monitoring)
5. [Advanced Indexing Techniques](#advanced-indexing-techniques)

## Index Types

### 1. B-tree Indexes

#### Overview
B-tree (balanced tree) indexes are the default and most commonly used index type in PostgreSQL. They are excellent for equality and range queries.

#### When to Use B-tree
- Equality conditions (`=`)
- Range conditions (`<`, `>`, `<=`, `>=`, `BETWEEN`)
- Pattern matching with prefixes (`LIKE 'prefix%'`)
- ORDER BY and DISTINCT operations

#### Creating B-tree Indexes
```sql
-- Single column B-tree index
CREATE INDEX idx_users_email ON users(email);

-- Composite B-tree index
CREATE INDEX idx_orders_user_date ON orders(user_id, order_date);

-- Unique B-tree index
CREATE INDEX idx_users_email_unique ON users(email);

-- Partial B-tree index
CREATE INDEX idx_active_users ON users(id) 
WHERE status = 'active';

-- Expression B-tree index
CREATE INDEX idx_users_lower_email ON users(LOWER(email));
```

#### B-tree Index Examples
```sql
-- Equality query
SELECT * FROM users WHERE email = 'john@example.com';

-- Range query
SELECT * FROM orders WHERE order_date > '2024-01-01';

-- Prefix pattern
SELECT * FROM products WHERE name LIKE 'Pro%';

-- ORDER BY
SELECT * FROM users ORDER BY created_at DESC;
```

### 2. Hash Indexes

#### Overview
Hash indexes are optimized for simple equality comparisons. They are generally faster than B-tree for equality but don't support range queries.

#### When to Use Hash
- Simple equality conditions (`=`)
- When you only need equality comparisons
- For very large tables with frequent equality lookups

#### Creating Hash Indexes
```sql
-- Hash index
CREATE INDEX idx_users_email_hash ON users USING HASH (email);

-- Composite hash index
CREATE INDEX idx_user_data_hash ON user_data USING HASH (user_id, data_key);
```

#### Hash Index Examples
```sql
-- Equality query
SELECT * FROM users WHERE email = 'john@example.com';

-- Hash join
SELECT * FROM user_data ud 
INNER JOIN users u ON ud.user_id = u.id 
WHERE ud.data_key = 'preferences';
```

### 3. GiST Indexes

#### Overview
GiST (Generalized Search Tree) indexes are useful for geometric data, full-text search, and other complex data types.

#### When to Use GiST
- Geographic data (PostGIS)
- Full-text search
- Network address data
- Any data requiring custom operators

#### Creating GiST Indexes
```sql
-- Geographic data
CREATE INDEX idx_locations_gist ON locations 
USING GIST (location);

-- Full-text search
CREATE INDEX idx_documents_gist ON documents 
USING GIST (to_tsvector(content));

-- Network data
CREATE INDEX idx_networks_gist ON networks 
USING GIST (network_range);
```

#### GiST Index Examples
```sql
-- Geographic query
SELECT * FROM locations 
WHERE ST_DWithin(location, ST_MakePoint(-122.4194, 37.7749), 1000);

-- Full-text search
SELECT * FROM documents 
WHERE to_tsvector(content) @@ to_tsquery('search terms');
```

### 4. GIN Indexes

#### Overview
GIN (Generalized Inverted Index) indexes are optimized for indexing composite values like arrays and JSONB.

#### When to Use GIN
- Array data
- JSONB data
- Any data with multiple values per row
- Full-text search (alternative to GiST)

#### Creating GIN Indexes
```sql
-- Array data
CREATE INDEX idx_users_tags_gin ON users 
USING GIN (tags);

-- JSONB data
CREATE INDEX idx_products_data_gin ON products 
USING GIN (data);

-- Full-text search
CREATE INDEX idx_documents_gin ON documents 
USING GIN (to_tsvector(content));
```

#### GIN Index Examples
```sql
-- Array query
SELECT * FROM users 
WHERE 'admin' = ANY(tags);

-- JSONB query
SELECT * FROM products 
WHERE data @> '{"category": "electronics"}';

-- Full-text search
SELECT * FROM documents 
WHERE to_tsvector(content) @@ to_tsquery('database & optimization');
```

### 5. BRIN Indexes

#### Overview
BRIN (Block Range Index) indexes are space-efficient for large tables with naturally ordered data.

#### When to Use BRIN
- Very large tables
- Naturally ordered data (timestamps, IDs)
- When space is a concern
- Read-heavy workloads

#### Creating BRIN Indexes
```sql
-- Timestamp data
CREATE INDEX idx_orders_brin ON orders 
USING BRIN (order_date);

-- ID data
CREATE INDEX idx_large_table_brin ON large_table 
USING BRIN (id);

-- Composite BRIN
CREATE INDEX idx_events_brin ON events 
USING BRIN (event_date, event_type);
```

#### BRIN Index Examples
```sql
-- Range query on large table
SELECT * FROM orders 
WHERE order_date BETWEEN '2024-01-01' AND '2024-01-31';

-- Ordered data access
SELECT * FROM events 
WHERE event_date > '2024-01-01' 
ORDER BY event_date;
```

## Index Creation Strategies

### 1. Single Column Indexes

#### Basic Strategy
```sql
-- Create index on frequently queried columns
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_orders_customer ON orders(customer_id);
```

#### When to Use Single Column
- Queries frequently filter on one column
- The column has high cardinality
- The table is moderately sized

### 2. Composite Indexes

#### Basic Strategy
```sql
-- Create composite index for common query patterns
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date);
CREATE INDEX idx_products_category_price ON products(category, price);
CREATE INDEX idx_users_status_created ON users(status, created_at);
```

#### Index Column Order
```sql
-- Put most selective columns first
CREATE INDEX idx_effective ON table(column1, column2, column3);

-- Equality columns before range columns
CREATE INDEX idx_orders_customer_date_status 
ON orders(customer_id, order_date, status);
```

#### When to Use Composite
- Queries frequently filter on multiple columns
- The combination of columns is selective
- The leading column is used in most queries

### 3. Partial Indexes

#### Basic Strategy
```sql
-- Index only active records
CREATE INDEX idx_active_users ON users(id) 
WHERE status = 'active';

-- Index recent orders
CREATE INDEX idx_recent_orders ON orders(id) 
WHERE order_date > NOW() - INTERVAL '1 month';

-- Index specific status
CREATE INDEX idx_pending_orders ON orders(id) 
WHERE status = 'pending';
```

#### When to Use Partial
- Only a subset of data is frequently queried
- The partial condition is selective
- You want to save space and maintenance overhead

### 4. Expression Indexes

#### Basic Strategy
```sql
-- Index on function results
CREATE INDEX idx_users_lower_email ON users(LOWER(email));
CREATE INDEX idx_products_category_upper ON products(UPPER(category));

-- Index on computed values
CREATE INDEX idx_orders_total_amount ON orders((quantity * price));
CREATE INDEX idx_users_full_name ON users((first_name || ' ' || last_name));
```

#### When to Use Expression
- Queries frequently use functions in WHERE clauses
- The expression is deterministic
- The function is immutable

### 5. Unique Indexes

#### Basic Strategy
```sql
-- Enforce uniqueness
CREATE UNIQUE INDEX idx_users_email_unique ON users(email);
CREATE UNIQUE INDEX idx_products_sku ON products(sku);

-- Composite unique index
CREATE UNIQUE INDEX idx_user_orders_unique 
ON orders(user_id, order_number);
```

#### When to Use Unique
- Data must be unique
- You want to enforce business rules
- You need fast uniqueness checks

## Performance Optimization

### 1. Index Usage Analysis

#### EXPLAIN Command
```sql
-- Analyze query execution plan
EXPLAIN SELECT * FROM users WHERE email = 'john@example.com';

-- Analyze with actual execution
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'john@example.com';

-- Detailed analysis
EXPLAIN (VERBOSE, ANALYZE, BUFFERS) 
SELECT * FROM users WHERE email = 'john@example.com';
```

#### Index Usage Statistics
```sql
-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Find unused indexes
SELECT 
    indexrelname AS index_name,
    relname AS table_name,
    idx_scan AS index_scans
FROM pg_stat_user_indexes 
JOIN pg_class ON pg_class.oid = pg_stat_user_indexes.indexrelid
WHERE idx_scan = 0;
```

### 2. Index Selection Guidelines

#### Cardinality Considerations
```sql
-- High cardinality columns (good for indexing)
SELECT COUNT(DISTINCT email) FROM users; -- High cardinality
SELECT COUNT(DISTINCT status) FROM users; -- Low cardinality

-- Index selectivity
SELECT 
    tablename,
    attname AS column,
    n_distinct AS distinct_values,
    CASE 
        WHEN n_distinct > 0 THEN n_distinct
        ELSE -n_distinct * reltuples
    END AS estimated_distinct
FROM pg_stats 
WHERE tablename = 'users' AND attname = 'email';
```

#### Size Considerations
```sql
-- Check index sizes
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;
```

#### Query Pattern Analysis
```sql
-- Analyze common query patterns
SELECT 
    query,
    calls,
    total_time,
    mean_time
FROM pg_stat_statements
WHERE query LIKE '%SELECT%FROM users%'
ORDER BY total_time DESC;
```

### 3. Index Maintenance

#### Index Creation Best Practices
```sql
-- Create indexes concurrently (doesn't lock table)
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);

-- Create indexes during low traffic periods
-- Use maintenance windows for large indexes
```

#### Index Rebuilding
```sql
-- Rebuild fragmented indexes
REINDEX INDEX idx_users_email;

-- Rebuild all indexes on a table
REINDEX TABLE users;

-- Online index rebuild
-- Use pg_repack extension for minimal downtime
```

#### Index Removal
```sql
-- Drop unused indexes
DROP INDEX IF EXISTS unused_index;

-- Drop concurrently
DROP INDEX CONCURRENTLY IF EXISTS unused_index;
```

## Advanced Indexing Techniques

### 1. Multicolumn Index Strategies

#### Leading Column Selection
```sql
-- Good: Leading column used in most queries
CREATE INDEX idx_orders_customer_date 
ON orders(customer_id, order_date);

-- Bad: Leading column rarely used alone
CREATE INDEX idx_orders_date_customer 
ON orders(order_date, customer_id); -- Less effective
```

#### Covering Indexes
```sql
-- Index that covers the query (no table access needed)
CREATE INDEX idx_orders_covering 
ON orders(customer_id, order_date, total_amount)
INCLUDE (shipping_address);

-- Query that uses covering index
SELECT customer_id, order_date, total_amount 
FROM orders 
WHERE customer_id = 123 AND order_date > '2024-01-01';
```

### 2. Partial Index Strategies

#### Selective Partial Indexes
```sql
-- Index only active users
CREATE INDEX idx_active_users ON users(id) 
WHERE status = 'active';

-- Index recent orders
CREATE INDEX idx_recent_orders ON orders(id) 
WHERE order_date > NOW() - INTERVAL '1 month';

-- Index specific status combinations
CREATE INDEX idx_pending_or_shipped ON orders(id) 
WHERE status IN ('pending', 'shipped');
```

#### Conditional Indexes
```sql
-- Index based on complex conditions
CREATE INDEX idx_large_orders ON orders(id) 
WHERE amount > 1000;

-- Index for reporting
CREATE INDEX idx_completed_orders ON orders(id) 
WHERE status = 'completed' AND completed_date IS NOT NULL;
```

### 3. Expression Index Strategies

#### Function-based Indexes
```sql
-- Index on lowercased email
CREATE INDEX idx_users_email_lower ON users(LOWER(email));

-- Index on date parts
CREATE INDEX idx_orders_year ON orders(EXTRACT(YEAR FROM order_date));
CREATE INDEX idx_orders_month ON orders(EXTRACT(MONTH FROM order_date));

-- Index on text search
CREATE INDEX idx_documents_search ON documents 
USING GIN (to_tsvector('english', content));
```

#### Computed Value Indexes
```sql
-- Index on calculated values
CREATE INDEX idx_orders_total ON orders((quantity * unit_price));
CREATE INDEX idx_users_age_group ON users((age / 10));
CREATE INDEX idx_products_price_range ON products((price / 100));
```

### 4. Partitioning and Indexing

#### Partitioned Table Indexing
```sql
-- Create indexes on partitioned tables
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    customer_id INTEGER,
    order_date TIMESTAMP,
    amount NUMERIC(10, 2)
) PARTITION BY RANGE (order_date);

-- Create local indexes
CREATE INDEX idx_orders_local ON orders(order_date);

-- Create global indexes
CREATE INDEX idx_orders_global ON orders(customer_id);
```

#### Partition-wise Indexing
```sql
-- Create indexes on each partition
CREATE TABLE orders_2024_01 PARTITION OF orders 
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE INDEX idx_orders_2024_01_date ON orders_2024_01(order_date);
```

## Monitoring and Maintenance

### 1. Index Health Monitoring

#### Index Statistics
```sql
-- Check index statistics
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    idx_blks_read,
    idx_blks_hit
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

#### Index Fragmentation
```sql
-- Check index fragmentation
SELECT 
    schemaname,
    tablename,
    indexname,
    (relpages * 8) AS size_kb,
    (relpages - ceil(reltuples / 300.0)) * 8 AS wasted_space_kb
FROM pg_stat_user_indexes 
JOIN pg_class ON pg_class.oid = pg_stat_user_indexes.indexrelid
WHERE relpages > ceil(reltuples / 300.0);
```

### 2. Performance Tuning

#### Index Tuning
```sql
-- Analyze query performance
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    shared_blks_hit,
    shared_blks_read
FROM pg_stat_statements
WHERE query LIKE '%SELECT%FROM orders%'
ORDER BY total_time DESC;
```

#### Index Recommendations
```sql
-- Use pg_stat_statements to identify missing indexes
-- Look for sequential scans on large tables
-- Identify frequent queries without index usage
```

### 3. Maintenance Tasks

#### Regular Maintenance
```sql
-- Rebuild fragmented indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS scans
FROM pg_stat_user_indexes
WHERE idx_scan < 100 AND pg_relation_size(indexrelid) > 1000000
ORDER BY pg_relation_size(indexrelid) DESC;
```

#### Vacuum and Analyze
```sql
-- Update statistics
ANALYZE users;
ANALYZE orders;

-- Vacuum indexes
VACUUM ANALYZE users;
VACUUM ANALYZE orders;
```

## Common Indexing Patterns

### 1. User Management
```sql
-- User table indexes
CREATE UNIQUE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_created ON users(created_at);
CREATE INDEX idx_users_last_login ON users(last_login);
```

### 2. E-commerce
```sql
-- Product table indexes
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_sku ON products(sku);

-- Order table indexes
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(status);

-- Order items indexes
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
```

### 3. Content Management
```sql
-- Articles table indexes
CREATE INDEX idx_articles_published ON articles(published_at);
CREATE INDEX idx_articles_author ON articles(author_id);
CREATE INDEX idx_articles_category ON articles(category_id);

-- Comments table indexes
CREATE INDEX idx_comments_article ON comments(article_id);
CREATE INDEX idx_comments_created ON comments(created_at);
```

### 4. Analytics
```sql
-- Events table indexes
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_timestamp ON events(event_timestamp);
CREATE INDEX idx_events_user ON events(user_id);

-- Metrics table indexes
CREATE INDEX idx_metrics_date ON metrics(metric_date);
CREATE INDEX idx_metrics_name ON metrics(metric_name);
```

## Best Practices

### 1. Index Creation

#### Start with Essential Indexes
```sql
-- Primary keys (automatically indexed)
-- Foreign keys
-- Frequently queried columns
-- Columns used in JOIN conditions
```

#### Monitor and Adjust
```sql
-- Monitor index usage regularly
-- Remove unused indexes
-- Add indexes based on query patterns
-- Rebuild fragmented indexes
```

### 2. Performance Considerations

#### Balance Read and Write Performance
```sql
-- Too many indexes slow down writes
-- Consider write-heavy vs read-heavy workloads
-- Use partial indexes to reduce overhead
```

#### Consider Storage Costs
```sql
-- Indexes consume storage space
-- Monitor index sizes
-- Use BRIN indexes for very large tables
-- Consider compression for large indexes
```

### 3. Query Optimization

#### Use EXPLAIN ANALYZE
```sql
-- Always analyze query plans
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'john@example.com';

-- Look for sequential scans
-- Check index usage
-- Analyze join strategies
```

#### Optimize Query Patterns
```sql
-- Use appropriate operators
-- Avoid functions on indexed columns
-- Use leading columns in composite indexes
-- Consider covering indexes
```

## Conclusion
Effective indexing is crucial for PostgreSQL performance. By understanding different index types, creating appropriate indexes based on query patterns, and maintaining them properly, you can significantly improve your database performance.

Remember to:
- Start with essential indexes (primary keys, foreign keys, frequent queries)
- Monitor index usage and remove unused indexes
- Consider the trade-off between read and write performance
- Use partial and expression indexes when appropriate
- Regularly maintain and rebuild fragmented indexes
- Analyze query patterns using EXPLAIN ANALYZE
- Consider storage costs and index sizes

With proper indexing strategies, you can ensure your PostgreSQL database performs optimally for your specific workload requirements.