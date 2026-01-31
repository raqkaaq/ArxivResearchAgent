# PostgreSQL Partitioning Strategies Guide

## Overview
This comprehensive guide covers PostgreSQL partitioning strategies, including table partitioning, partition management, performance optimization, and best practices for implementing scalable database solutions.

## Table of Contents
1. [Partitioning Types](#partitioning-types)
2. [Partition Management](#partition-management)
3. [Performance Optimization](#performance-optimization)
4. [Advanced Strategies](#advanced-strategies)
5. [Maintenance](#maintenance)

## Partitioning Types

### 1. Range Partitioning

#### Basic Range Partitioning
```sql
-- Create partitioned table
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    customer_id INTEGER,
    order_date TIMESTAMP,
    amount NUMERIC(12, 2),
    status VARCHAR(20)
) PARTITION BY RANGE (order_date);

-- Create monthly partitions
CREATE TABLE orders_2024_01 PARTITION OF orders 
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE orders_2024_02 PARTITION OF orders 
FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Create yearly partition
CREATE TABLE orders_2024 PARTITION OF orders 
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01')
PARTITION BY MONTH;

-- Create monthly partitions for 2024
CREATE TABLE orders_2024_01 PARTITION OF orders_2024 
FOR VALUES FROM (1) TO (2);

CREATE TABLE orders_2024_02 PARTITION OF orders_2024 
FOR VALUES FROM (2) TO (3);
```

#### Range Partitioning with Default
```sql
-- Create partitioned table with default partition
CREATE TABLE events (
    id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(50),
    event_time TIMESTAMP,
    data JSONB
) PARTITION BY RANGE (event_time);

-- Create specific partitions
CREATE TABLE events_2024_01 PARTITION OF events 
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE events_2024_02 PARTITION OF events 
FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Create default partition for future dates
CREATE TABLE events_default PARTITION OF events 
DEFAULT;
```

### 2. List Partitioning

#### Basic List Partitioning
```sql
-- Create list partitioned table
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100),
    country_code VARCHAR(2),
    created_at TIMESTAMP
) PARTITION BY LIST (country_code);

-- Create partitions for specific countries
CREATE TABLE users_us PARTITION OF users 
FOR VALUES IN ('US', 'USA');

CREATE TABLE users_uk PARTITION OF users 
FOR VALUES IN ('GB', 'UK');

CREATE TABLE users_eu PARTITION OF users 
FOR VALUES IN ('DE', 'FR', 'IT', 'ES', 'NL');

-- Create default partition
CREATE TABLE users_other PARTITION OF users 
DEFAULT;
```

#### List Partitioning with Multiple Columns
```sql
-- Create multi-column list partitioning
CREATE TABLE sales (
    id BIGSERIAL PRIMARY KEY,
    region VARCHAR(50),
    product_category VARCHAR(50),
    sale_date TIMESTAMP,
    amount NUMERIC(12, 2)
) PARTITION BY LIST ((region, product_category));

-- Create partitions for specific combinations
CREATE TABLE sales_north_electronics PARTITION OF sales 
FOR VALUES IN (('North', 'Electronics'));

CREATE TABLE sales_south_clothing PARTITION OF sales 
FOR VALUES IN (('South', 'Clothing'));

CREATE TABLE sales_default PARTITION OF sales 
DEFAULT;
```

### 3. Hash Partitioning

#### Basic Hash Partitioning
```sql
-- Create hash partitioned table
CREATE TABLE logs (
    id BIGSERIAL PRIMARY KEY,
    log_level VARCHAR(10),
    message TEXT,
    created_at TIMESTAMP
) PARTITION BY HASH (id);

-- Create 4 partitions
CREATE TABLE logs_0 PARTITION OF logs 
FOR VALUES WITH (MODULUS 4, REMAINDER 0);

CREATE TABLE logs_1 PARTITION OF logs 
FOR VALUES WITH (MODULUS 4, REMAINDER 1);

CREATE TABLE logs_2 PARTITION OF logs 
FOR VALUES WITH (MODULUS 4, REMAINDER 2);

CREATE TABLE logs_3 PARTITION OF logs 
FOR VALUES WITH (MODULUS 4, REMAINDER 3);
```

#### Hash Partitioning with Multiple Columns
```sql
-- Create multi-column hash partitioning
CREATE TABLE transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER,
    transaction_type VARCHAR(20),
    amount NUMERIC(12, 2),
    created_at TIMESTAMP
) PARTITION BY HASH (user_id, transaction_type);

-- Create 8 partitions
CREATE TABLE transactions_0 PARTITION OF transactions 
FOR VALUES WITH (MODULUS 8, REMAINDER 0);

CREATE TABLE transactions_1 PARTITION OF transactions 
FOR VALUES WITH (MODULUS 8, REMAINDER 1);

-- ... up to 7
```

## Partition Management

### 1. Creating Partitions

#### Automated Partition Creation
```sql
-- Function to create monthly partitions
CREATE OR REPLACE FUNCTION create_monthly_partitions()
RETURNS VOID AS $$
DECLARE
    year_month TEXT;
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    -- Create partitions for next 12 months
    FOR i IN 0..11 LOOP
        start_date := DATE_TRUNC('month', CURRENT_DATE + INTERVAL '' || i || ' months');
        end_date := start_date + INTERVAL '1 month';
        year_month := TO_CHAR(start_date, 'YYYY_MM');
        partition_name := 'orders_' || year_month;
        
        -- Create partition if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM pg_partitions 
            WHERE partitionname = partition_name
        ) THEN
            EXECUTE format(
                'CREATE TABLE %I PARTITION OF orders FOR VALUES FROM (%L) TO (%L)',
                partition_name, start_date, end_date
            );
            RAISE NOTICE 'Created partition: %', partition_name;
        END IF;
    END LOOP;
END;
$$
LANGUAGE plpgsql;

-- Create partitions
SELECT create_monthly_partitions();
```

#### Partition Templates
```sql
-- Create partition template
CREATE TABLE sales_template (
    LIKE sales INCLUDING ALL,
    CONSTRAINT sales_template_check CHECK (false)
);

-- Create indexes on template
CREATE INDEX idx_sales_template_date ON sales_template(sale_date);
CREATE INDEX idx_sales_template_region ON sales_template(region);

-- Create partitions using template
CREATE TABLE sales_2024_01 PARTITION OF sales 
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01')
WITH (template = sales_template);
```

### 2. Managing Partitions

#### Adding Partitions
```sql
-- Add new partition manually
CREATE TABLE orders_2024_03 PARTITION OF orders 
FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');

-- Add partition with specific tablespace
CREATE TABLE orders_2024_03 PARTITION OF orders 
FOR VALUES FROM ('2024-03-01') TO ('2024-04-01')
TABLESPACE fast_ssd;
```

#### Removing Partitions
```sql
-- Remove partition (data is kept)
ALTER TABLE orders DETACH PARTITION orders_2024_01;

-- Drop partition (data is deleted)
DROP TABLE orders_2024_01;

-- Archive partition
ALTER TABLE orders DETACH PARTITION orders_2024_01;
ALTER TABLE orders_2024_01 SET TABLESPACE archive;
```

#### Merging Partitions
```sql
-- Merge partitions by detaching and recreating
-- Step 1: Detach partitions
ALTER TABLE sales DETACH PARTITION sales_north_electronics;
ALTER TABLE sales DETACH PARTITION sales_north_clothing;

-- Step 2: Create merged partition
CREATE TABLE sales_north_combined PARTITION OF sales 
FOR VALUES IN (('North', 'Electronics'), ('North', 'Clothing'));

-- Step 3: Move data
INSERT INTO sales_north_combined 
SELECT * FROM sales_north_electronics;
INSERT INTO sales_north_combined 
SELECT * FROM sales_north_clothing;
```

### 3. Partition Pruning

#### Query Optimization
```sql
-- Enable partition pruning
SET enable_partition_pruning = on;

-- Test query with partition pruning
EXPLAIN (COSTS OFF, VERBOSE)
SELECT * FROM orders 
WHERE order_date BETWEEN '2024-01-15' AND '2024-01-20';

-- Check which partitions are scanned
EXPLAIN (COSTS OFF, VERBOSE, ANALYZE)
SELECT * FROM orders 
WHERE order_date BETWEEN '2024-01-15' AND '2024-01-20';
```

#### Constraint Exclusion
```sql
-- Enable constraint exclusion
SET constraint_exclusion = on;

-- Test constraint exclusion
EXPLAIN (COSTS OFF, VERBOSE)
SELECT * FROM orders 
WHERE order_date < '2024-01-01';
```

## Performance Optimization

### 1. Index Optimization

#### Local Indexes
```sql
-- Create local indexes on partitions
CREATE INDEX idx_orders_2024_01_date ON orders_2024_01(order_date);
CREATE INDEX idx_orders_2024_01_customer ON orders_2024_01(customer_id);

-- Create indexes on all partitions
CREATE INDEX CONCURRENTLY idx_orders_date_local 
ON ONLY orders (order_date) LOCAL;
```

#### Global Indexes
```sql
-- Create global index for cross-partition queries
CREATE INDEX idx_orders_global_customer ON orders(customer_id);

-- Create unique global index
CREATE UNIQUE INDEX idx_orders_global_id ON orders(id);
```

#### Index Maintenance
```sql
-- Rebuild partition indexes
REINDEX TABLE orders_2024_01;

-- Rebuild all partition indexes
REINDEX TABLE orders;
```

### 2. Query Optimization

#### Partition-Aware Queries
```sql
-- Optimize for partition pruning
SELECT * FROM orders 
WHERE order_date BETWEEN '2024-01-15' AND '2024-01-20';

-- Use partition key in WHERE clause
SELECT * FROM orders 
WHERE order_date > '2024-01-01' AND customer_id = 123;

-- Avoid non-partition key filters first
-- Bad: SELECT * FROM orders WHERE customer_id = 123 AND order_date > '2024-01-01';
-- Good: SELECT * FROM orders WHERE order_date > '2024-01-01' AND customer_id = 123;
```

#### Parallel Query Execution
```sql
-- Enable parallel query execution
SET max_parallel_workers_per_gather = 4;

-- Test parallel execution
EXPLAIN (COSTS OFF, VERBOSE, ANALYZE)
SELECT * FROM orders 
WHERE order_date BETWEEN '2024-01-01' AND '2024-01-31';
```

### 3. Bulk Operations

#### Bulk Insert Optimization
```sql
-- Use COPY for bulk inserts
COPY orders (customer_id, order_date, amount, status)
FROM '/orders_2024_01.csv' WITH (FORMAT csv);

-- Use multi-row INSERT
INSERT INTO orders (customer_id, order_date, amount, status)
SELECT 
    generate_series(1, 1000),
    DATE '2024-01-15' + (random() * 30)::integer,
    random() * 1000,
    'pending'
FROM generate_series(1, 1000);
```

#### Bulk Update Optimization
```sql
-- Update multiple partitions efficiently
UPDATE orders 
SET status = 'completed'
WHERE order_date BETWEEN '2024-01-01' AND '2024-01-31'
  AND status = 'pending';
```

## Advanced Strategies

### 1. Sub-partitioning

#### Time-based Sub-partitioning
```sql
-- Create table with time-based sub-partitioning
CREATE TABLE events (
    id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(50),
    event_time TIMESTAMP,
    data JSONB
) PARTITION BY RANGE (event_time);

-- Create yearly partitions
CREATE TABLE events_2024 PARTITION OF events 
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01')
PARTITION BY RANGE (event_time);

-- Create monthly sub-partitions
CREATE TABLE events_2024_01 PARTITION OF events_2024 
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01')
PARTITION BY RANGE (event_time);

CREATE TABLE events_2024_01_01 PARTITION OF events_2024_01 
FOR VALUES FROM ('2024-01-01') TO ('2024-01-02');

CREATE TABLE events_2024_01_02 PARTITION OF events_2024_01 
FOR VALUES FROM ('2024-01-02') TO ('2024-01-03');
```

#### Multi-level Sub-partitioning
```sql
-- Create complex multi-level partitioning
CREATE TABLE sales (
    id BIGSERIAL PRIMARY KEY,
    region VARCHAR(50),
    product_category VARCHAR(50),
    sale_date TIMESTAMP,
    amount NUMERIC(12, 2)
) PARTITION BY LIST (region);

-- Create regional partitions
CREATE TABLE sales_north PARTITION OF sales 
FOR VALUES IN ('North') PARTITION BY RANGE (sale_date);

CREATE TABLE sales_south PARTITION OF sales 
FOR VALUES IN ('South') PARTITION BY RANGE (sale_date);

-- Create date partitions for North region
CREATE TABLE sales_north_2024 PARTITION OF sales_north 
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01')
PARTITION BY RANGE (sale_date);

CREATE TABLE sales_north_2024_01 PARTITION OF sales_north_2024 
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

### 2. Partitioned Tables with Inheritance

#### Traditional Inheritance Approach
```sql
-- Create parent table
CREATE TABLE measurements (
    logdate DATE NOT NULL,
    peaktemp INTEGER,
    unitsales INTEGER
);

-- Create child partitions
CREATE TABLE measurements_y2021 PARTITION OF measurements 
FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');

CREATE TABLE measurements_y2022 PARTITION OF measurements 
FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');

-- Create indexes on child tables
CREATE INDEX idx_measurements_y2021_date ON measurements_y2021(logdate);
CREATE INDEX idx_measurements_y2022_date ON measurements_y2022(logdate);
```

#### Constraint-Based Partitioning
```sql
-- Create parent table with constraints
CREATE TABLE sales (
    id BIGSERIAL PRIMARY KEY,
    region VARCHAR(50),
    product_category VARCHAR(50),
    sale_date TIMESTAMP,
    amount NUMERIC(12, 2),
    CONSTRAINT valid_region CHECK (region IN ('North', 'South', 'East', 'West'))
);

-- Create child tables with constraints
CREATE TABLE sales_north (
    CHECK (region = 'North')
) INHERITS (sales);

CREATE TABLE sales_south (
    CHECK (region = 'South')
) INHERITS (sales);

-- Create triggers for constraint enforcement
CREATE OR REPLACE FUNCTION sales_insert_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.region = 'North' THEN
        INSERT INTO sales_north VALUES (NEW.*);
    ELSIF NEW.region = 'South' THEN
        INSERT INTO sales_south VALUES (NEW.*);
    ELSE
        RAISE EXCEPTION 'Invalid region: %', NEW.region;
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER sales_insert_trigger
BEFORE INSERT ON sales
FOR EACH ROW EXECUTE FUNCTION sales_insert_trigger();
```

### 3. Partitioned Tables with Foreign Data Wrappers

#### Partitioned Tables with FDW
```sql
-- Create foreign table for partitioning
CREATE EXTENSION file_fdw;

CREATE SERVER file_server FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE sales_2024_01_ext (
    id BIGINT,
    region VARCHAR(50),
    product_category VARCHAR(50),
    sale_date TIMESTAMP,
    amount NUMERIC(12, 2)
)
SERVER file_server
OPTIONS (filename '/sales/2024_01.csv', format 'csv');

-- Create local partition that references foreign data
CREATE TABLE sales_2024_01 PARTITION OF sales 
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01')
FOREIGN TABLE sales_2024_01_ext;
```

## Maintenance

### 1. Partition Maintenance Tasks

#### Regular Maintenance
```sql
-- Analyze partitions
ANALYZE orders_2024_01;
ANALYZE orders_2024_02;

-- Vacuum partitions
VACUUM orders_2024_01;
VACUUM orders_2024_02;

-- Reindex partitions
REINDEX TABLE orders_2024_01;
REINDEX TABLE orders_2024_02;
```

#### Automated Maintenance
```sql
-- Create maintenance function
CREATE OR REPLACE FUNCTION maintain_partitions()
RETURNS VOID AS $$
DECLARE
    partition_name TEXT;
    partition_date DATE;
BEGIN
    -- Drop old partitions (older than 6 months)
    FOR partition_name IN 
        SELECT partitionname 
        FROM pg_partitions 
        WHERE tablename = 'orders' 
        AND partitionbounds LIKE 'FOR VALUES FROM%TO%'
        AND partitionbounds < 'FOR VALUES FROM ('2023-07-01') TO ('2023-08-01')'
    LOOP
        EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
        RAISE NOTICE 'Dropped partition: %', partition_name;
    END LOOP;
    
    -- Create new partitions
    PERFORM create_monthly_partitions();
END;
$$
LANGUAGE plpgsql;

-- Schedule maintenance
-- Daily cron job: SELECT maintain_partitions();
```

### 2. Monitoring Partitions

#### Partition Statistics
```sql
-- Monitor partition sizes
SELECT 
    schemaname,
    tablename,
    partitions,
    partitions_heap_blks,
    partitions_idx_blks,
    partitions_toast_blks
FROM pg_stat_user_tables
WHERE tablename = 'orders';

-- Check partition usage
SELECT 
    partitionname,
    partitionbounds,
    pg_size_pretty(pg_total_relation_size(partitiontablename)) AS size
FROM pg_partitions 
WHERE tablename = 'orders'
ORDER BY partitionname;
```

#### Query Performance Monitoring
```sql
-- Monitor partition query performance
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    shared_blks_hit,
    shared_blks_read,
    substring(query from 10 for 100) AS short_query
FROM pg_stat_statements
WHERE query LIKE '%SELECT%FROM orders%'
ORDER BY total_time DESC
LIMIT 10;
```

## Common Patterns

### 1. Time-series Data
```sql
-- Time-series partitioning pattern
CREATE TABLE metrics (
    id BIGSERIAL PRIMARY KEY,
    metric_name VARCHAR(50),
    metric_value NUMERIC(12, 2),
    metric_time TIMESTAMP
) PARTITION BY RANGE (metric_time);

-- Create daily partitions
CREATE TABLE metrics_2024_01_01 PARTITION OF metrics 
FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2024-01-02 00:00:00');

CREATE TABLE metrics_2024_01_02 PARTITION OF metrics 
FOR VALUES FROM ('2024-01-02 00:00:00') TO ('2024-01-03 00:00:00');
```

### 2. Multi-tenant Applications
```sql
-- Multi-tenant partitioning pattern
CREATE TABLE tenant_data (
    id BIGSERIAL PRIMARY KEY,
    tenant_id INTEGER,
    data_type VARCHAR(50),
    data_value TEXT,
    created_at TIMESTAMP
) PARTITION BY LIST (tenant_id);

-- Create partitions for each tenant
CREATE TABLE tenant_data_1 PARTITION OF tenant_data 
FOR VALUES IN (1);

CREATE TABLE tenant_data_2 PARTITION OF tenant_data 
FOR VALUES IN (2);

-- Create indexes on tenant partitions
CREATE INDEX idx_tenant_data_1_type ON tenant_data_1(data_type);
CREATE INDEX idx_tenant_data_2_type ON tenant_data_2(data_type);
```

### 3. Geographical Data
```sql
-- Geographical partitioning pattern
CREATE TABLE locations (
    id BIGSERIAL PRIMARY KEY,
    region VARCHAR(50),
    country VARCHAR(50),
    city VARCHAR(50),
    coordinates POINT,
    created_at TIMESTAMP
) PARTITION BY LIST (region);

-- Create regional partitions
CREATE TABLE locations_north_america PARTITION OF locations 
FOR VALUES IN ('North America');

CREATE TABLE locations_europe PARTITION OF locations 
FOR VALUES IN ('Europe');

CREATE TABLE locations_asia PARTITION OF locations 
FOR VALUES IN ('Asia');
```

## Best Practices

### 1. Partition Design

#### Choose Appropriate Partition Key
```sql
-- Good: Use frequently filtered column
CREATE TABLE orders PARTITION BY RANGE (order_date);

-- Good: Use high-cardinality column
CREATE TABLE users PARTITION BY HASH (id);

-- Avoid: Low-cardinality columns
-- Bad: CREATE TABLE orders PARTITION BY LIST (status); -- Only a few statuses
```

#### Partition Size
```sql
-- Aim for partitions of 10-50 million rows
-- Or 5-20GB in size
-- Adjust based on your hardware and query patterns
```

### 2. Performance Optimization

#### Index Strategy
```sql
-- Create local indexes on partition keys
CREATE INDEX idx_orders_date_local ON orders(order_date) LOCAL;

-- Create global indexes for cross-partition queries
CREATE INDEX idx_orders_customer_global ON orders(customer_id);

-- Use partial indexes for selective queries
CREATE INDEX idx_active_orders ON orders(id) WHERE status = 'active';
```

#### Query Optimization
```sql
-- Use partition key in WHERE clauses
SELECT * FROM orders WHERE order_date > '2024-01-01';

-- Avoid functions on partition keys
-- Bad: WHERE EXTRACT(YEAR FROM order_date) = 2024
-- Good: WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
```

### 3. Maintenance Strategy

#### Automated Partition Management
```sql
-- Create automated partition management
CREATE OR REPLACE FUNCTION manage_partitions()
RETURNS TRIGGER AS $$
BEGIN
    -- Create new partitions as needed
    -- Drop old partitions
    -- Update statistics
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

-- Schedule regular maintenance
-- Daily: Create new partitions, update statistics
-- Weekly: Reindex, vacuum analyze
-- Monthly: Review partition strategy
```

### 4. Monitoring and Alerting

#### Partition Monitoring
```sql
-- Monitor partition health
SELECT 
    partitionname,
    partitionbounds,
    pg_size_pretty(pg_total_relation_size(partitiontablename)) AS size,
    n_tup_ins AS inserts,
    n_tup_upd AS updates,
    n_tup_del AS deletes,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows
FROM pg_stat_user_tables
WHERE tablename = 'orders';
```

#### Performance Alerts
```sql
-- Set up alerts for partition issues
-- Large partition size
-- Low cache hit ratio
-- High I/O wait times
-- Slow query performance
```

## Conclusion
PostgreSQL partitioning is a powerful feature for managing large datasets and improving query performance. By choosing appropriate partitioning strategies, following best practices, and implementing proper maintenance procedures, you can create scalable and efficient database solutions.

Remember to:
- Choose the right partitioning type for your data
- Keep partitions at manageable sizes
- Create appropriate indexes
- Optimize queries for partition pruning
- Implement automated partition management
- Monitor partition health regularly
- Test performance under realistic workloads
- Consider future growth when designing partitions
- Document your partitioning strategy
- Regularly review and adjust as needed

With proper implementation of partitioning strategies, you can significantly improve your PostgreSQL database performance and scalability while maintaining data manageability and query efficiency.