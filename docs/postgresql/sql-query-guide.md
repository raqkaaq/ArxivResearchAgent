# PostgreSQL Comprehensive SQL Query Guide

## Overview
This comprehensive guide covers all aspects of SQL querying in PostgreSQL, from basic SELECT statements to advanced analytical queries and performance optimization techniques.

## Table of Contents
1. [Basic Query Operations](#basic-query-operations)
2. [Advanced Query Techniques](#advanced-query-techniques)
3. [Data Manipulation](#data-manipulation)
4. [Performance Optimization](#performance-optimization)
5. [Analytical Queries](#analytical-queries)
6. [Window Functions](#window-functions)
7. [Common Table Expressions](#common-table-expressions)
8. [Query Patterns](#query-patterns)

## Basic Query Operations

### 1. SELECT Statements

#### Basic SELECT
```sql
-- Select all columns from a table
SELECT * FROM users;

-- Select specific columns
SELECT id, name, email FROM users;

-- Select with aliases
SELECT id AS user_id, name AS full_name FROM users;

-- Select with expressions
SELECT id, name, email, created_at, 
       EXTRACT(YEAR FROM created_at) AS signup_year
FROM users;
```

#### SELECT with WHERE Clause
```sql
-- Basic filtering
SELECT * FROM users WHERE status = 'active';

-- Multiple conditions
SELECT * FROM users 
WHERE status = 'active' AND last_login > NOW() - INTERVAL '30 days';

-- Range conditions
SELECT * FROM orders 
WHERE order_date BETWEEN '2024-01-01' AND '2024-12-31';

-- Pattern matching
SELECT * FROM users WHERE email LIKE '%@example.com';

-- NULL checking
SELECT * FROM users WHERE email IS NOT NULL;
```

#### SELECT with ORDER BY
```sql
-- Basic ordering
SELECT * FROM users ORDER BY created_at DESC;

-- Multiple columns
SELECT * FROM users ORDER BY last_name ASC, first_name ASC;

-- Custom ordering
SELECT * FROM products 
ORDER BY CASE 
    WHEN category = 'electronics' THEN 1
    WHEN category = 'clothing' THEN 2
    ELSE 3
END;
```

#### SELECT with LIMIT and OFFSET
```sql
-- Pagination
SELECT * FROM users ORDER BY id LIMIT 10 OFFSET 20;

-- Top N results
SELECT * FROM products ORDER BY price DESC LIMIT 5;

-- Random selection
SELECT * FROM users ORDER BY RANDOM() LIMIT 10;
```

### 2. JOIN Operations

#### INNER JOIN
```sql
-- Basic inner join
SELECT u.id, u.name, o.order_id, o.order_date
FROM users u
INNER JOIN orders o ON u.id = o.user_id;

-- Multiple joins
SELECT u.name, p.product_name, oi.quantity, oi.price
FROM users u
INNER JOIN orders o ON u.id = o.user_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.id;
```

#### LEFT JOIN
```sql
-- Users with or without orders
SELECT u.id, u.name, COUNT(o.order_id) AS order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.name;

-- Include NULL values
SELECT u.name, o.order_id
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE o.order_id IS NULL;
```

#### RIGHT JOIN and FULL OUTER JOIN
```sql
-- Right join (less common)
SELECT p.product_name, oi.quantity
FROM products p
RIGHT JOIN order_items oi ON p.id = oi.product_id;

-- Full outer join
SELECT u.name, o.order_id
FROM users u
FULL OUTER JOIN orders o ON u.id = o.user_id;
```

#### CROSS JOIN
```sql
-- Cartesian product
SELECT u.name, p.product_name
FROM users u
CROSS JOIN products p;

-- Generate combinations
SELECT d1.day, d2.hour
FROM days d1
CROSS JOIN hours d2;
```

#### JOIN with Conditions
```sql
-- Join with additional conditions
SELECT u.name, o.order_id, o.total_amount
FROM users u
INNER JOIN orders o ON u.id = o.user_id AND o.status = 'completed';

-- Non-equi join
SELECT e1.name AS employee, e2.name AS manager
FROM employees e1
INNER JOIN employees e2 ON e1.manager_id = e2.id;
```

### 3. Subqueries

#### Scalar Subqueries
```sql
-- Single value subquery
SELECT * FROM users 
WHERE created_at = (SELECT MIN(created_at) FROM users);

-- Correlated subquery
SELECT u.name, u.email
FROM users u
WHERE u.id = (SELECT user_id FROM orders 
              WHERE user_id = u.id 
              ORDER BY order_date DESC 
              LIMIT 1);
```

#### Inline Views (Derived Tables)
```sql
-- Subquery in FROM clause
SELECT t.category, AVG(t.total_amount) AS avg_amount
FROM (
    SELECT category, SUM(amount) AS total_amount
    FROM transactions
    GROUP BY category
) t
GROUP BY t.category;

-- Complex derived table
SELECT u.name, recent_orders.total_orders
FROM users u
INNER JOIN (
    SELECT user_id, COUNT(*) AS total_orders
    FROM orders
    WHERE order_date > NOW() - INTERVAL '30 days'
    GROUP BY user_id
) recent_orders ON u.id = recent_orders.user_id;
```

#### EXISTS and NOT EXISTS
```sql
-- Check for existence
SELECT * FROM users u
WHERE EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.user_id = u.id AND o.status = 'completed'
);

-- Check for non-existence
SELECT * FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.user_id = u.id AND o.status = 'completed'
);
```

#### ANY, SOME, and ALL
```sql
-- ANY comparison
SELECT * FROM products 
WHERE price < ANY (SELECT price FROM products WHERE category = 'electronics');

-- ALL comparison
SELECT * FROM products 
WHERE price < ALL (SELECT price FROM products WHERE category = 'electronics');

-- SOME (synonym for ANY)
SELECT * FROM products 
WHERE price < SOME (SELECT price FROM products WHERE category = 'electronics');
```

## Advanced Query Techniques

### 1. Aggregation Functions

#### Basic Aggregates
```sql
-- Count and count distinct
SELECT COUNT(*) AS total_users, 
       COUNT(DISTINCT email) AS unique_emails
FROM users;

-- Sum and average
SELECT SUM(amount) AS total_sales, 
       AVG(amount) AS avg_sale
FROM orders;

-- Min and max
SELECT MIN(created_at) AS earliest, 
       MAX(created_at) AS latest
FROM users;
```

#### GROUP BY Operations
```sql
-- Group by single column
SELECT category, COUNT(*) AS product_count
FROM products
GROUP BY category;

-- Group by multiple columns
SELECT category, brand, COUNT(*) AS product_count
FROM products
GROUP BY category, brand;

-- Group by with having
SELECT category, COUNT(*) AS product_count
FROM products
GROUP BY category
HAVING COUNT(*) > 10;
```

#### Conditional Aggregation
```sql
-- Conditional counts
SELECT 
    COUNT(*) AS total,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) AS completed,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) AS pending
FROM orders;

-- Conditional sums
SELECT 
    SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END) AS completed_sales,
    SUM(CASE WHEN status = 'pending' THEN amount ELSE 0 END) AS pending_sales
FROM orders;
```

### 2. Set Operations

#### UNION and UNION ALL
```sql
-- Combine results from multiple queries
SELECT name, email FROM users
UNION
SELECT full_name, contact_email FROM customers;

-- Include duplicates
SELECT name FROM users
UNION ALL
SELECT name FROM customers;
```

#### INTERSECT
```sql
-- Find common records
SELECT user_id FROM orders
INTERSECT
SELECT user_id FROM premium_users;
```

#### EXCEPT (MINUS)
```sql
-- Find records in first query but not second
SELECT user_id FROM users
EXCEPT
SELECT user_id FROM inactive_users;
```

### 3. Common Table Expressions (CTEs)

#### Simple CTE
```sql
WITH recent_orders AS (
    SELECT user_id, COUNT(*) AS order_count
    FROM orders
    WHERE order_date > NOW() - INTERVAL '30 days'
    GROUP BY user_id
)
SELECT u.name, ro.order_count
FROM users u
INNER JOIN recent_orders ro ON u.id = ro.user_id;
```

#### Recursive CTE
```sql
-- Hierarchical data (organizational structure)
WITH RECURSIVE employee_hierarchy AS (
    -- Base case: top-level managers
    SELECT id, name, manager_id, 1 AS level
    FROM employees
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive case: subordinates
    SELECT e.id, e.name, e.manager_id, eh.level + 1
    FROM employees e
    INNER JOIN employee_hierarchy eh ON e.manager_id = eh.id
)
SELECT * FROM employee_hierarchy;
```

#### Multiple CTEs
```sql
WITH customer_orders AS (
    SELECT user_id, COUNT(*) AS total_orders
    FROM orders
    GROUP BY user_id
),
order_totals AS (
    SELECT user_id, SUM(amount) AS total_spent
    FROM orders
    GROUP BY user_id
)
SELECT c.name, co.total_orders, ot.total_spent
FROM users c
INNER JOIN customer_orders co ON c.id = co.user_id
INNER JOIN order_totals ot ON c.id = ot.user_id;
```

## Data Manipulation

### 1. INSERT Statements

#### Basic INSERT
```sql
-- Insert single row
INSERT INTO users (name, email, created_at)
VALUES ('John Doe', 'john@example.com', NOW());

-- Insert multiple rows
INSERT INTO users (name, email, created_at)
VALUES
    ('Jane Smith', 'jane@example.com', NOW()),
    ('Bob Johnson', 'bob@example.com', NOW());
```

#### INSERT with SELECT
```sql
-- Insert from another table
INSERT INTO active_users (id, name, email)
SELECT id, name, email 
FROM users 
WHERE status = 'active';

-- Insert with transformation
INSERT INTO user_stats (user_id, order_count, total_spent)
SELECT user_id, COUNT(*), SUM(amount)
FROM orders
GROUP BY user_id;
```

#### INSERT with ON CONFLICT
```sql
-- Upsert (update or insert)
INSERT INTO users (id, name, email)
VALUES (1, 'John Doe', 'john@example.com')
ON CONFLICT (id) 
DO UPDATE SET 
    name = EXCLUDED.name,
    email = EXCLUDED.email;

-- Ignore conflicts
INSERT INTO users (id, name, email)
VALUES (1, 'John Doe', 'john@example.com')
ON CONFLICT (id) 
DO NOTHING;
```

### 2. UPDATE Statements

#### Basic UPDATE
```sql
-- Update single column
UPDATE users 
SET email = 'newemail@example.com'
WHERE id = 1;

-- Update multiple columns
UPDATE users 
SET email = 'newemail@example.com',
    updated_at = NOW(),
    status = 'verified'
WHERE id = 1;
```

#### UPDATE with FROM
```sql
-- Update using data from another table
UPDATE users u
SET status = 'active', last_login = o.order_date
FROM orders o
WHERE u.id = o.user_id 
  AND o.order_date = (SELECT MAX(order_date) 
                     FROM orders 
                     WHERE user_id = u.id);
```

#### UPDATE with RETURNING
```sql
-- Get updated rows
UPDATE users 
SET status = 'active'
WHERE last_login > NOW() - INTERVAL '30 days'
RETURNING id, name, email, status;

-- Use updated values
UPDATE users 
SET email = 'newemail@example.com'
WHERE id = 1
RETURNING id, name, email;
```

### 3. DELETE Statements

#### Basic DELETE
```sql
-- Delete specific rows
DELETE FROM users 
WHERE status = 'inactive' AND last_login < NOW() - INTERVAL '1 year';

-- Delete with conditions
DELETE FROM orders 
WHERE status = 'cancelled' AND created_at < NOW() - INTERVAL '30 days';
```

#### DELETE with USING
```sql
-- Delete using data from another table
DELETE FROM users u
USING orders o
WHERE u.id = o.user_id 
  AND o.status = 'cancelled' 
  AND o.created_at < NOW() - INTERVAL '30 days';
```

#### DELETE with RETURNING
```sql
-- Get deleted rows
DELETE FROM users 
WHERE status = 'inactive'
RETURNING id, name, email;

-- Use deleted values
DELETE FROM temp_table 
WHERE created_at < NOW() - INTERVAL '1 hour'
RETURNING *;
```

## Performance Optimization

### 1. Index Optimization

#### Creating Indexes
```sql
-- Single column index
CREATE INDEX idx_users_email ON users(email);

-- Composite index
CREATE INDEX idx_orders_user_date ON orders(user_id, order_date);

-- Partial index
CREATE INDEX idx_active_users ON users(id) 
WHERE status = 'active';

-- Unique index
CREATE UNIQUE INDEX idx_users_email_unique ON users(email);

-- Expression index
CREATE INDEX idx_users_lower_email ON users(LOWER(email));
```

#### Index Usage Analysis
```sql
-- Check index usage
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'john@example.com';

-- List all indexes
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'users';

-- Check index statistics
SELECT * FROM pg_stat_user_indexes 
WHERE indexrelname = 'idx_users_email';
```

### 2. Query Optimization

#### EXPLAIN and ANALYZE
```sql
-- Basic explain
EXPLAIN SELECT * FROM users WHERE email = 'john@example.com';

-- Explain with actual execution plan
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'john@example.com';

-- Verbose explain
EXPLAIN (VERBOSE, ANALYZE, BUFFERS) 
SELECT * FROM users WHERE email = 'john@example.com';
```

#### Query Hints
```sql
-- Force index usage
SELECT * FROM users USE INDEX (idx_users_email) 
WHERE email = 'john@example.com';

-- Parallel query
SET max_parallel_workers_per_gather = 4;

-- Enable sequential scan
SET enable_seqscan = on;
```

#### Common Performance Issues
```sql
-- Check for sequential scans
EXPLAIN SELECT * FROM large_table;

-- Monitor slow queries
SELECT query, duration, rows
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > INTERVAL '1 minute';
```

## Analytical Queries

### 1. Statistical Functions

#### Basic Statistics
```sql
-- Average and standard deviation
SELECT AVG(price) AS avg_price, 
       STDDEV(price) AS stddev_price,
       VARIANCE(price) AS variance_price
FROM products;

-- Correlation
SELECT CORR(x, y) AS correlation
FROM data_points;
```

#### Percentiles and Quartiles
```sql
-- Median (50th percentile)
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) AS median_price
FROM products;

-- Quartiles
SELECT 
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY price) AS q1,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY price) AS q3
FROM products;
```

#### Mode and Frequency
```sql
-- Most common value
SELECT category, COUNT(*) AS frequency
FROM products
GROUP BY category
ORDER BY frequency DESC
LIMIT 1;
```

### 2. Time Series Analysis

#### Time-based Aggregation
```sql
-- Daily aggregation
SELECT 
    DATE_TRUNC('day', order_date) AS order_day,
    COUNT(*) AS order_count,
    SUM(amount) AS total_sales
FROM orders
GROUP BY DATE_TRUNC('day', order_date)
ORDER BY order_day;

-- Monthly aggregation
SELECT 
    DATE_TRUNC('month', order_date) AS order_month,
    COUNT(*) AS order_count,
    SUM(amount) AS total_sales
FROM orders
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY order_month;
```

#### Moving Averages
```sql
-- Simple moving average
SELECT 
    order_date,
    amount,
    AVG(amount) OVER (
        ORDER BY order_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS 7_day_avg
FROM orders
ORDER BY order_date;
```

#### Cumulative Sums
```sql
-- Running total
SELECT 
    order_date,
    amount,
    SUM(amount) OVER (
        ORDER BY order_date 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM orders
ORDER BY order_date;
```

## Window Functions

### 1. Basic Window Functions

#### ROW_NUMBER
```sql
-- Rank rows within partitions
SELECT 
    id,
    name,
    email,
    ROW_NUMBER() OVER (ORDER BY created_at DESC) AS row_num
FROM users;

-- Rank within groups
SELECT 
    category,
    product_name,
    price,
    ROW_NUMBER() OVER (PARTITION BY category ORDER BY price DESC) AS rank_in_category
FROM products;
```

#### RANK and DENSE_RANK
```sql
-- Standard ranking with gaps
SELECT 
    id,
    name,
    score,
    RANK() OVER (ORDER BY score DESC) AS rank
FROM users;

-- Dense ranking without gaps
SELECT 
    id,
    name,
    score,
    DENSE_RANK() OVER (ORDER BY score DESC) AS dense_rank
FROM users;
```

#### NTILE
```sql
-- Divide into buckets
SELECT 
    id,
    name,
    score,
    NTILE(4) OVER (ORDER BY score DESC) AS quartile
FROM users;
```

### 2. Advanced Window Functions

#### LAG and LEAD
```sql
-- Compare with previous row
SELECT 
    order_date,
    amount,
    LAG(amount) OVER (ORDER BY order_date) AS previous_amount,
    amount - LAG(amount) OVER (ORDER BY order_date) AS change
FROM orders
ORDER BY order_date;

-- Compare with next row
SELECT 
    order_date,
    amount,
    LEAD(amount) OVER (ORDER BY order_date) AS next_amount
FROM orders
ORDER BY order_date;
```

#### FIRST_VALUE and LAST_VALUE
```sql
-- First value in partition
SELECT 
    category,
    product_name,
    price,
    FIRST_VALUE(product_name) OVER (
        PARTITION BY category 
        ORDER BY price DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS most_expensive
FROM products;
```

#### CUME_DIST and PERCENT_RANK
```sql
-- Cumulative distribution
SELECT 
    id,
    name,
    score,
    CUME_DIST() OVER (ORDER BY score DESC) AS cumulative_distribution
FROM users;

-- Percent rank
SELECT 
    id,
    name,
    score,
    PERCENT_RANK() OVER (ORDER BY score DESC) AS percent_rank
FROM users;
```

## Common Table Expressions

### 1. Simple CTEs

#### Basic CTE
```sql
WITH monthly_sales AS (
    SELECT 
        DATE_TRUNC('month', order_date) AS month,
        SUM(amount) AS total_sales
    FROM orders
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT month, total_sales
FROM monthly_sales
ORDER BY month;
```

#### Multiple CTEs
```sql
WITH customer_stats AS (
    SELECT 
        user_id,
        COUNT(*) AS order_count,
        SUM(amount) AS total_spent
    FROM orders
    GROUP BY user_id
),
active_customers AS (
    SELECT user_id
    FROM orders
    WHERE order_date > NOW() - INTERVAL '30 days'
    GROUP BY user_id
)
SELECT c.name, cs.order_count, cs.total_spent
FROM users c
INNER JOIN customer_stats cs ON c.id = cs.user_id
INNER JOIN active_customers ac ON c.id = ac.user_id;
```

### 2. Recursive CTEs

#### Hierarchical Data
```sql
-- Organizational structure
WITH RECURSIVE org_chart AS (
    -- Base case: top-level managers
    SELECT id, name, manager_id, 1 AS level
    FROM employees
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive case: subordinates
    SELECT e.id, e.name, e.manager_id, oc.level + 1
    FROM employees e
    INNER JOIN org_chart oc ON e.manager_id = oc.id
)
SELECT * FROM org_chart;
```

#### Tree Traversal
```sql
-- Category hierarchy
WITH RECURSIVE category_tree AS (
    -- Base case: root categories
    SELECT id, name, parent_id, 1 AS depth
    FROM categories
    WHERE parent_id IS NULL
    
    UNION ALL
    
    -- Recursive case: child categories
    SELECT c.id, c.name, c.parent_id, ct.depth + 1
    FROM categories c
    INNER JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT * FROM category_tree;
```

## Query Patterns

### 1. Pagination

#### Offset-based Pagination
```sql
-- Basic pagination
SELECT * FROM users 
ORDER BY created_at DESC 
LIMIT 10 OFFSET 0;

-- Next page
SELECT * FROM users 
ORDER BY created_at DESC 
LIMIT 10 OFFSET 10;
```

#### Cursor-based Pagination
```sql
-- First page
SELECT * FROM users 
WHERE created_at < NOW()
ORDER BY created_at DESC 
LIMIT 10;

-- Next page (using last seen cursor)
SELECT * FROM users 
WHERE created_at < '2024-01-15 10:30:00'
ORDER BY created_at DESC 
LIMIT 10;
```

### 2. Search and Filtering

#### Full-text Search
```sql
-- Basic full-text search
SELECT * FROM documents 
WHERE to_tsvector(content) @@ to_tsquery('search terms');

-- Weighted search
SELECT * FROM documents 
WHERE to_tsvector('pg_catalog.english', title || ' ' || content) @@ to_tsquery('pg_catalog.english', 'search terms');
```

#### Complex Filtering
```sql
-- Multiple filter conditions
SELECT * FROM products 
WHERE (category = 'electronics' OR category = 'computers')
  AND price BETWEEN 100 AND 1000
  AND (features && ARRAY['wifi', 'bluetooth'])
  AND rating >= 4.0;
```

### 3. Data Aggregation

#### Grouped Aggregation
```sql
-- Group by multiple columns
SELECT 
    category,
    brand,
    COUNT(*) AS product_count,
    AVG(price) AS avg_price,
    MAX(price) AS max_price
FROM products
GROUP BY category, brand;

-- Conditional aggregation
SELECT 
    category,
    COUNT(*) AS total,
    COUNT(CASE WHEN price > 100 THEN 1 END) AS premium_count,
    SUM(CASE WHEN price > 100 THEN 1 ELSE 0 END) AS premium_total
FROM products
GROUP BY category;
```

#### Time-based Aggregation
```sql
-- Hourly aggregation
SELECT 
    DATE_TRUNC('hour', created_at) AS hour,
    COUNT(*) AS count,
    SUM(amount) AS total
FROM orders
GROUP BY DATE_TRUNC('hour', created_at)
ORDER BY hour;

-- Weekly aggregation
SELECT 
    DATE_TRUNC('week', created_at) AS week,
    COUNT(*) AS count,
    SUM(amount) AS total
FROM orders
GROUP BY DATE_TRUNC('week', created_at)
ORDER BY week;
```

## Best Practices

### 1. Query Design

#### Use Explicit JOINs
```sql
-- Good: Explicit JOIN
SELECT u.name, o.order_id
FROM users u
INNER JOIN orders o ON u.id = o.user_id;

-- Avoid: Implicit JOIN
SELECT u.name, o.order_id
FROM users u, orders o
WHERE u.id = o.user_id;
```

#### Use Parameterized Queries
```sql
-- Use parameters to prevent SQL injection
PREPARE get_user_by_email(text) AS
SELECT * FROM users WHERE email = $1;

EXECUTE get_user_by_email('john@example.com');
```

#### Avoid SELECT *
```sql
-- Specify columns explicitly
SELECT id, name, email, created_at FROM users;

-- Avoid
SELECT * FROM users;
```

### 2. Performance Tips

#### Use Indexes Wisely
```sql
-- Create indexes on frequently queried columns
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_user_date ON orders(user_id, order_date);

-- Drop unused indexes
DROP INDEX CONCURRENTLY IF EXISTS unused_index;
```

#### Monitor Query Performance
```sql
-- Check slow queries
SELECT query, mean_time, calls
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

-- Analyze query plans
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'john@example.com';
```

#### Use Connection Pooling
```sql
-- Configure connection pool
jdbc:postgresql://localhost:5432/mydb?prepareThreshold=3&preparedStatementCacheQueries=100
```

## Common Patterns

### 1. Finding Top N Records
```sql
-- Top 10 most expensive products
SELECT * FROM products 
ORDER BY price DESC 
LIMIT 10;

-- Top product in each category
SELECT DISTINCT ON (category) category, product_name, price
FROM products
ORDER BY category, price DESC;
```

### 2. Finding Duplicates
```sql
-- Find duplicate emails
SELECT email, COUNT(*) 
FROM users
GROUP BY email
HAVING COUNT(*) > 1;

-- Find duplicate rows
SELECT *, COUNT(*) 
FROM users
GROUP BY id, name, email
HAVING COUNT(*) > 1;
```

### 3. Data Validation
```sql
-- Check referential integrity
SELECT o.id
FROM orders o
LEFT JOIN users u ON o.user_id = u.id
WHERE u.id IS NULL;

-- Validate data types
SELECT * FROM users 
WHERE email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
```

## Conclusion
This comprehensive SQL query guide covers the essential techniques and patterns for working with PostgreSQL databases. By mastering these concepts and following best practices, you can write efficient, maintainable, and high-performance SQL queries that meet your application's needs.

Remember to:
- Always use EXPLAIN ANALYZE to understand query performance
- Create appropriate indexes based on query patterns
- Use parameterized queries to prevent SQL injection
- Monitor and optimize slow queries regularly
- Follow consistent naming conventions and coding standards

With practice and experience, you'll develop the skills to write complex, optimized SQL queries that can handle any data manipulation or analysis task required by your applications.