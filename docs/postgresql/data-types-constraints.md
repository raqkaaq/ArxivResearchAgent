# PostgreSQL Data Types and Constraints Guide

## Overview
This comprehensive guide covers PostgreSQL data types, constraints, and their usage patterns. Understanding data types and constraints is crucial for designing efficient and reliable database schemas.

## Table of Contents
1. [Data Types](#data-types)
2. [Constraints](#constraints)
3. [Type Casting and Conversion](#type-casting-and-conversion)
4. [Domain Types](#domain-types)
5. [Best Practices](#best-practices)

## Data Types

### 1. Numeric Types

#### Integer Types
```sql
-- Small integer (2 bytes)
SMALLINT
INTEGER -- Alias: INT
BIGINT

-- Examples
CREATE TABLE test_numbers (
    id SERIAL PRIMARY KEY,
    small_num SMALLINT,
    int_num INTEGER,
    big_num BIGINT
);

-- Insert values
INSERT INTO test_numbers (small_num, int_num, big_num)
VALUES (32767, 2147483647, 9223372036854775807);
```

#### Floating-Point Types
```sql
-- Single precision (4 bytes)
REAL

-- Double precision (8 bytes)
DOUBLE PRECISION

-- Examples
CREATE TABLE test_floats (
    id SERIAL PRIMARY KEY,
    real_num REAL,
    double_num DOUBLE PRECISION
);

-- Insert values
INSERT INTO test_floats (real_num, double_num)
VALUES (3.141592653589793, 3.141592653589793);
```

#### Exact Decimal Types
```sql
-- DECIMAL/NUMERIC (arbitrary precision)
DECIMAL(precision, scale)
NUMERIC(precision, scale)

-- Examples
CREATE TABLE test_decimals (
    id SERIAL PRIMARY KEY,
    price NUMERIC(10, 2),
    large_num NUMERIC(20, 0)
);

-- Insert values
INSERT INTO test_decimals (price, large_num)
VALUES (19.99, 12345678901234567890);
```

#### Serial Types
```sql
-- Auto-incrementing integers
SERIAL -- 4-byte auto-increment
BIGSERIAL -- 8-byte auto-increment

-- Examples
CREATE TABLE test_serial (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100)
);

-- Insert without specifying ID
INSERT INTO test_serial (name) VALUES ('Test Record');
```

### 2. Character Types

#### Fixed-Length Character
```sql
-- CHAR(n) - fixed length, padded with spaces
CHAR(10)

-- Examples
CREATE TABLE test_chars (
    id SERIAL PRIMARY KEY,
    fixed_char CHAR(10),
    variable_char VARCHAR(50)
);

-- Insert values
INSERT INTO test_chars (fixed_char, variable_char)
VALUES ('Hello', 'Hello World');
```

#### Variable-Length Character
```sql
-- VARCHAR(n) - variable length with limit
VARCHAR(255)

-- TEXT - unlimited variable length
TEXT

-- Examples
CREATE TABLE test_texts (
    id SERIAL PRIMARY KEY,
    short_text VARCHAR(100),
    long_text TEXT
);

-- Insert values
INSERT INTO test_texts (short_text, long_text)
VALUES ('Short text', 'This is a very long text that can be unlimited in length');
```

#### String Functions
```sql
-- String manipulation
SELECT 
    name,
    LENGTH(name) AS length,
    UPPER(name) AS uppercase,
    LOWER(name) AS lowercase,
    TRIM(name) AS trimmed
FROM users;

-- Pattern matching
SELECT * FROM users 
WHERE email LIKE '%@example.com';

-- String concatenation
SELECT first_name || ' ' || last_name AS full_name
FROM users;
```

### 3. Date and Time Types

#### Date and Time Types
```sql
-- DATE - date only
DATE

-- TIME - time only
TIME

-- TIMESTAMP - date and time
TIMESTAMP

-- TIMESTAMP WITH TIME ZONE
TIMESTAMPTZ

-- INTERVAL - time interval
INTERVAL

-- Examples
CREATE TABLE test_dates (
    id SERIAL PRIMARY KEY,
    birth_date DATE,
    meeting_time TIME,
    created_at TIMESTAMP,
    event_time TIMESTAMPTZ,
    duration INTERVAL
);

-- Insert values
INSERT INTO test_dates (birth_date, meeting_time, created_at, event_time, duration)
VALUES (
    '2024-01-15', 
    )10:30:00', 
    NOW(), 
    NOW() AT TIME ZONE 'UTC', 
    'P1D' -- 1 day interval
);
```

#### Date/Time Functions
```sql
-- Current date and time
SELECT 
    CURRENT_DATE,
    CURRENT_TIME,
    CURRENT_TIMESTAMP,
    LOCALTIME,
    LOCALTIMESTAMP;

-- Date arithmetic
SELECT 
    created_at,
    created_at + INTERVAL '30 days' AS thirty_days_later,
    created_at - INTERVAL '1 month' AS one_month_ago
FROM users;

-- Extract parts
SELECT 
    created_at,
    EXTRACT(YEAR FROM created_at) AS year,
    EXTRACT(MONTH FROM created_at) AS month,
    EXTRACT(DAY FROM created_at) AS day
FROM users;
```

### 4. Boolean Type

```sql
-- BOOLEAN - true/false values
BOOLEAN

-- Examples
CREATE TABLE test_booleans (
    id SERIAL PRIMARY KEY,
    is_active BOOLEAN,
    has_permission BOOLEAN DEFAULT true
);

-- Insert values
INSERT INTO test_booleans (is_active, has_permission)
VALUES (true, false);

-- Query with boolean
SELECT * FROM users 
WHERE is_active = true;
```

### 5. Binary Data Types

```sql
-- BYTEA - binary data
BYTEA

-- Examples
CREATE TABLE test_binary (
    id SERIAL PRIMARY KEY,
    file_data BYTEA
);

-- Insert binary data
INSERT INTO test_binary (file_data)
VALUES (DECODE('504B0304', 'hex')); -- Example: ZIP file header
```

### 6. Array Types

```sql
-- Array of any data type
INTEGER[], TEXT[], VARCHAR(50)[]

-- Examples
CREATE TABLE test_arrays (
    id SERIAL PRIMARY KEY,
    int_array INTEGER[],
    text_array TEXT[],
    varchar_array VARCHAR(50)[]
);

-- Insert array values
INSERT INTO test_arrays (int_array, text_array, varchar_array)
VALUES (
    ARRAY[1, 2, 3, 4, 5],
    ARRAY['apple', 'banana', 'orange'],
    ARRAY['item1', 'item2', 'item3']
);

-- Query arrays
SELECT * FROM test_arrays 
WHERE 3 = ANY(int_array);

-- Array functions
SELECT 
    int_array,
    ARRAY_LENGTH(int_array, 1) AS array_length,
    UNNEST(int_array) AS array_elements
FROM test_arrays;
```

### 7. JSON and JSONB Types

```sql
-- JSON - text representation
JSON

-- JSONB - binary representation (more efficient)
JSONB

-- Examples
CREATE TABLE test_json (
    id SERIAL PRIMARY KEY,
    config JSON,
    data JSONB
);

-- Insert JSON data
INSERT INTO test_json (config, data)
VALUES (
    '{"name": "John", "age": 30}',
    '{"name": "John", "age": 30, "hobbies": ["reading", "gaming"]}'
);

-- Query JSON data
SELECT * FROM test_json 
WHERE data @> '{"name": "John"}';

-- JSON functions
SELECT 
    config,
    config->'name' AS name,
    config->'age' AS age,
    jsonb_array_length(data->hobbies) AS hobbies_count
FROM test_json;
```

### 8. UUID Type

```sql
-- UUID - universally unique identifier
UUID

-- Examples
CREATE TABLE test_uuid (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100)
);

-- Insert with UUID
INSERT INTO test_uuid (name) VALUES ('Test Record');

-- Generate UUID
SELECT gen_random_uuid();
```

## Constraints

### 1. NOT NULL Constraint

```sql
-- Ensures column cannot have NULL values
CREATE TABLE test_not_null (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL
);

-- Insert with NOT NULL
INSERT INTO test_not_null (name, email) VALUES ('John Doe', 'john@example.com');

-- This will fail
INSERT INTO test_not_null (name) VALUES ('Jane Doe'); -- Missing email
```

### 2. UNIQUE Constraint

```sql
-- Ensures column values are unique
CREATE TABLE test_unique (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE,
    username VARCHAR(50) UNIQUE
);

-- Insert unique values
INSERT INTO test_unique (email, username) 
VALUES ('john@example.com', 'johndoe');

-- This will fail (duplicate email)
INSERT INTO test_unique (email, username) 
VALUES ('john@example.com', 'janedoe');
```

### 3. PRIMARY KEY Constraint

```sql
-- Combines NOT NULL and UNIQUE
CREATE TABLE test_primary_key (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100)
);

-- Composite primary key
CREATE TABLE test_composite_pk (
    user_id INTEGER,
    order_id INTEGER,
    product_id INTEGER,
    PRIMARY KEY (user_id, order_id, product_id)
);
```

### 4. FOREIGN KEY Constraint

```sql
-- Creates relationship between tables
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    order_date TIMESTAMP DEFAULT NOW()
);

-- Add foreign key constraint
ALTER TABLE orders 
ADD CONSTRAINT fk_user 
FOREIGN KEY (user_id) REFERENCES users(id);

-- ON DELETE options
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    order_date TIMESTAMP DEFAULT NOW()
);

-- ON UPDATE options
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON UPDATE CASCADE,
    order_date TIMESTAMP DEFAULT NOW()
);
```

### 5. CHECK Constraint

```sql
-- Validates data based on condition
CREATE TABLE test_check (
    id SERIAL PRIMARY KEY,
    age INTEGER CHECK (age >= 18),
    email VARCHAR(255) CHECK (email LIKE '%@%.%')
);

-- Multiple conditions
CREATE TABLE test_multiple_checks (
    id SERIAL PRIMARY KEY,
    price NUMERIC(10, 2) CHECK (price > 0),
    quantity INTEGER CHECK (quantity >= 0 AND quantity <= 1000)
);

-- Complex check
CREATE TABLE test_complex_check (
    id SERIAL PRIMARY KEY,
    status VARCHAR(20) CHECK (status IN ('pending', 'approved', 'rejected')),
    amount NUMERIC(10, 2) CHECK (
        (status = 'approved' AND amount > 0) OR 
        (status IN ('pending', 'rejected') AND amount IS NULL)
    )
);
```

### 6. EXCLUDE Constraint

```sql
-- Prevents overlapping ranges
CREATE TABLE test_exclude (
    id SERIAL PRIMARY KEY,
    room_id INTEGER,
    booking_date DATE,
    booking_time TSTZRANGE,
    EXCLUDE USING GIST (room_id WITH =, booking_time WITH &&)
);

-- Example usage
INSERT INTO test_exclude (room_id, booking_date, booking_time)
VALUES (1, 'today', '[2024-01-15 10:00, 2024-01-15 12:00]');

-- This will fail (overlapping time)
INSERT INTO test_exclude (room_id, booking_date, booking_time)
VALUES (1, 'today', '[2024-01-15 11:00, 2024-01-15 13:00]');
```

## Type Casting and Conversion

### 1. Implicit Casting

```sql
-- Automatic conversion in operations
SELECT 1 + 2.5; -- Integer + Float = Float
SELECT '2024-01-15' + INTERVAL '30 days'; -- Date + Interval
```

### 2. Explicit Casting

```sql
-- Using CAST function
SELECT CAST('10' AS INTEGER);
SELECT CAST('123.45' AS NUMERIC(10, 2));

-- Using :: operator
SELECT '123.45'::NUMERIC(10, 2);
SELECT NOW()::DATE;
SELECT '{"name": "John"}'::JSONB;
```

### 3. Type Conversion Functions

```sql
-- Numeric conversions
SELECT 
    ROUND(123.456, 2) AS rounded,
    TRUNC(123.456, 1) AS truncated,
    CEIL(123.456) AS ceiling,
    FLOOR(123.456) AS floor;

-- String conversions
SELECT 
    'Hello' AS original,
    UPPER('Hello') AS uppercase,
    LOWER('Hello') AS lowercase,
    INITCAP('hello world') AS capitalized;

-- Date conversions
SELECT 
    '2024-01-15' AS date_str,
    'January 15, 2024'::DATE AS parsed_date,
    TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS') AS formatted_date;
```

## Domain Types

### 1. Creating Domains

```sql
-- Create custom domain
CREATE DOMAIN positive_integer AS INTEGER 
CHECK (VALUE > 0);

CREATE DOMAIN email_address AS VARCHAR(255) 
CHECK (VALUE ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- Use domains
CREATE TABLE test_domains (
    id SERIAL PRIMARY KEY,
    age positive_integer,
    email email_address
);

-- Insert with domains
INSERT INTO test_domains (age, email) 
VALUES (25, 'john@example.com');

-- This will fail (invalid domain)
INSERT INTO test_domains (age, email) 
VALUES (-5, 'invalid-email');
```

### 2. Domain Functions

```sql
-- Create domain with default
CREATE DOMAIN status_type AS VARCHAR(20) 
DEFAULT 'pending' 
CHECK (VALUE IN ('pending', 'approved', 'rejected'));

-- Use domain with default
CREATE TABLE test_domain_defaults (
    id SERIAL PRIMARY KEY,
    status status_type
);

-- Insert without specifying status
INSERT INTO test_domain_defaults DEFAULT VALUES;
-- status will be 'pending'
```

## Best Practices

### 1. Choosing Appropriate Data Types

#### Use the Smallest Appropriate Type
```sql
-- Good: Appropriate size
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    age SMALLINT CHECK (age BETWEEN 0 AND 150),
    rating DECIMAL(3, 2) CHECK (rating BETWEEN 0 AND 5)
);

-- Avoid: Oversized types
CREATE TABLE users (
    id BIGINT, -- Unnecessary for most applications
    age INTEGER, -- Can use SMALLINT
    rating FLOAT -- Use DECIMAL for exact precision
);
```

#### Use Appropriate String Types
```sql
-- Good: Appropriate string types
CREATE TABLE users (
    username VARCHAR(50), -- Fixed reasonable length
    bio TEXT -- Unlimited length
);

-- Avoid: CHAR for variable-length data
CREATE TABLE users (
    username CHAR(100), -- Pads with spaces
    bio CHAR(1000) -- Inefficient for variable content
);
```

### 2. Constraint Design

#### Use Constraints for Data Integrity
```sql
-- Good: Proper constraints
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    status VARCHAR(20) CHECK (status IN ('pending', 'shipped', 'delivered')),
    amount NUMERIC(10, 2) CHECK (amount > 0)
);

-- Avoid: No constraints
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER, -- Can be NULL
    status VARCHAR(20), -- Any value allowed
    amount NUMERIC(10, 2) -- Can be negative
);
```

#### Use Composite Constraints
```sql
-- Good: Composite constraints
CREATE TABLE order_items (
    order_id INTEGER,
    product_id INTEGER,
    quantity INTEGER CHECK (quantity > 0),
    price NUMERIC(10, 2) CHECK (price > 0),
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);
```

### 3. Performance Considerations

#### Index Considerations
```sql
-- Good: Appropriate indexing
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_user_date ON orders(user_id, order_date);

-- Avoid: Over-indexing
CREATE INDEX idx_users_name ON users(name); -- Rarely queried
CREATE INDEX idx_users_everything ON users(id, name, email, created_at); -- Too broad
```

#### Type Selection for Performance
```sql
-- Good: Efficient types
CREATE TABLE logs (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    message TEXT
);

-- Avoid: Inefficient types
CREATE TABLE logs (
    id NUMERIC(20, 0) PRIMARY KEY, -- Slower than BIGSERIAL
    created_at VARCHAR(50), -- Should be TIMESTAMP
    message VARCHAR(1000) -- Use TEXT for unlimited length
);
```

### 4. Storage Optimization

#### Use Appropriate Storage
```sql
-- Good: Optimized storage
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200),
    description TEXT,
    price NUMERIC(10, 2),
    weight DECIMAL(8, 3)
);

-- Avoid: Wasted storage
CREATE TABLE products (
    id BIGINT, -- Can use SERIAL
    name CHAR(500), -- Use VARCHAR
    description VARCHAR(10000), -- Use TEXT
    price FLOAT, -- Use NUMERIC for exact precision
    weight REAL -- Use DECIMAL for exact precision
);
```

## Common Pitfalls

### 1. Type Mismatches

```sql
-- Problem: Implicit conversions
SELECT * FROM users 
WHERE id = '123'; -- String compared to integer

-- Solution: Explicit casting
SELECT * FROM users 
WHERE id = '123'::INTEGER;
```

### 2. Precision Loss

```sql
-- Problem: Float precision issues
SELECT 0.1 + 0.2; -- May not equal 0.3 exactly

-- Solution: Use NUMERIC for exact precision
SELECT NUMERIC '0.1' + NUMERIC '0.2'; -- Exact result
```

### 3. Time Zone Issues

```sql
-- Problem: Time zone confusion
SELECT NOW(); -- Server time zone
SELECT NOW() AT TIME ZONE 'UTC'; -- Convert to UTC

-- Solution: Use TIMESTAMPTZ consistently
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    event_time TIMESTAMPTZ DEFAULT NOW() -- Stores with time zone
);
```

## Conclusion
Understanding PostgreSQL data types and constraints is essential for designing robust and efficient database schemas. By choosing appropriate data types, implementing proper constraints, and following best practices, you can ensure data integrity, optimize performance, and create maintainable database structures.

Remember to:
- Choose the smallest appropriate data type
- Implement constraints for data integrity
- Use domains for reusable validation rules
- Consider performance implications of type choices
- Handle time zones consistently
- Use appropriate indexing strategies

With proper understanding and application of data types and constraints, you can create PostgreSQL databases that are both efficient and reliable.