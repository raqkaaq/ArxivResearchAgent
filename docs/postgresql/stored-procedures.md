# PostgreSQL PL/pgSQL Stored Procedures Guide

## Overview
This comprehensive guide covers PostgreSQL stored procedures using PL/pgSQL, including function creation, advanced features, error handling, and best practices for developing efficient database procedures.

## Table of Contents
1. [Basic Function Creation](#basic-function-creation)
2. [Advanced Features](#advanced-features)
3. [Error Handling](#error-handling)
4. [Performance Optimization](#performance-optimization)
5. [Security Considerations](#security-considerations)
6. [Best Practices](#best-practices)

## Basic Function Creation

### 1. Simple Functions

#### Function Syntax
```sql
-- Basic function structure
CREATE OR REPLACE FUNCTION function_name(
    param1 datatype,
    param2 datatype DEFAULT default_value
)
RETURNS return_datatype AS $$
BEGIN
    -- Function body
    RETURN result;
END;
$$
LANGUAGE plpgsql;
```

#### Example: Simple Calculation
```sql
-- Function to calculate total amount
CREATE OR REPLACE FUNCTION calculate_total(
    quantity INTEGER,
    price NUMERIC(10, 2)
)
RETURNS NUMERIC(10, 2) AS $$
BEGIN
    RETURN quantity * price;
END;
$$
LANGUAGE plpgsql;

-- Call the function
SELECT calculate_total(5, 19.99);
```

#### Example: String Manipulation
```sql
-- Function to format full name
CREATE OR REPLACE FUNCTION format_full_name(
    first_name VARCHAR(50),
    last_name VARCHAR(50)
)
RETURNS VARCHAR(102) AS $$
BEGIN
    RETURN TRIM(first_name) || ' ' || TRIM(last_name);
END;
$$
LANGUAGE plpgsql;

-- Call the function
SELECT format_full_name(' John ', ' Doe ');
```

### 2. Functions with Multiple Statements

#### Example: Complex Logic
```sql
-- Function to calculate order total with tax
CREATE OR REPLACE FUNCTION calculate_order_total(
    order_id INTEGER
)
RETURNS NUMERIC(12, 2) AS $$
DECLARE
    subtotal NUMERIC(12, 2);
    tax_rate NUMERIC(5, 4) := 0.0875;
    tax_amount NUMERIC(12, 2);
    total_amount NUMERIC(12, 2);
BEGIN
    -- Get subtotal from order items
    SELECT COALESCE(SUM(quantity * price), 0)
    INTO subtotal
    FROM order_items
    WHERE order_id = calculate_order_total.order_id;
    
    -- Calculate tax
    tax_amount := subtotal * tax_rate;
    
    -- Calculate total
    total_amount := subtotal + tax_amount;
    
    RETURN total_amount;
END;
$$
LANGUAGE plpgsql;

-- Call the function
SELECT calculate_order_total(123);
```

#### Example: Conditional Logic
```sql
-- Function to determine user status
CREATE OR REPLACE FUNCTION get_user_status(
    user_id INTEGER
)
RETURNS VARCHAR(20) AS $$
DECLARE
    last_login TIMESTAMP;
    signup_date TIMESTAMP;
    status VARCHAR(20);
BEGIN
    -- Get user data
    SELECT last_login, created_at
    INTO last_login, signup_date
    FROM users
    WHERE id = get_user_status.user_id;
    
    -- Determine status
    IF last_login IS NULL THEN
        status := 'never_logged_in';
    ELSIF last_login < NOW() - INTERVAL '1 year' THEN
        status := 'inactive';
    ELSIF last_login < NOW() - INTERVAL '30 days' THEN
        status := 'occasional';
    ELSE
        status := 'active';
    END IF;
    
    RETURN status;
END;
$$
LANGUAGE plpgsql;

-- Call the function
SELECT get_user_status(456);
```

### 3. Functions with OUT Parameters

#### Example: Multiple Return Values
```sql
-- Function to get user details
CREATE OR REPLACE FUNCTION get_user_details(
    user_id INTEGER,
    OUT full_name VARCHAR(102),
    OUT email VARCHAR(255),
    OUT status VARCHAR(20)
)
AS $$
BEGIN
    SELECT 
        first_name || ' ' || last_name,
        email,
        CASE 
            WHEN last_login IS NULL THEN 'never_logged_in'
            WHEN last_login < NOW() - INTERVAL '1 year' THEN 'inactive'
            ELSE 'active'
        END
    INTO full_name, email, status
    FROM users
    WHERE id = get_user_details.user_id;
END;
$$
LANGUAGE plpgsql;

-- Call the function
SELECT * FROM get_user_details(123);
```

#### Example: Complex Data Structure
```sql
-- Function to get order summary
CREATE OR REPLACE FUNCTION get_order_summary(
    order_id INTEGER,
    OUT order_id INTEGER,
    OUT customer_name VARCHAR(100),
    OUT total_amount NUMERIC(12, 2),
    OUT item_count INTEGER,
    OUT status VARCHAR(20)
)
AS $$
BEGIN
    SELECT 
        o.id,
        c.first_name || ' ' || c.last_name,
        SUM(oi.quantity * oi.price),
        COUNT(oi.id),
        o.status
    INTO order_id, customer_name, total_amount, item_count, status
    FROM orders o
    INNER JOIN customers c ON o.customer_id = c.id
    INNER JOIN order_items oi ON o.id = oi.order_id
    WHERE o.id = get_order_summary.order_id
    GROUP BY o.id, c.first_name, c.last_name, o.status;
END;
$$
LANGUAGE plpgsql;

-- Call the function
SELECT * FROM get_order_summary(123);
```

## Advanced Features

### 1. Functions with VARIADIC Parameters

#### Example: Flexible Arguments
```sql
-- Function to calculate average of variable arguments
CREATE OR REPLACE FUNCTION calculate_average(
    VARIADIC numbers NUMERIC[]
)
RETURNS NUMERIC AS $$
DECLARE
    sum_value NUMERIC := 0;
    count_value INTEGER := 0;
BEGIN
    FOREACH sum_value IN ARRAY numbers LOOP
        sum_value := sum_value + sum_value;
        count_value := count_value + 1;
    END LOOP;
    
    IF count_value = 0 THEN
        RETURN NULL;
    ELSE
        RETURN sum_value / count_value;
    END IF;
END;
$$
LANGUAGE plpgsql;

-- Call the function
SELECT calculate_average(10, 20, 30, 40, 50);
SELECT calculate_average(VARIADIC ARRAY[1.5, 2.5, 3.5]);
```

### 2. Functions with Default Parameters

#### Example: Optional Parameters
```sql
-- Function with default parameters
CREATE OR REPLACE FUNCTION search_products(
    search_term VARCHAR(100),
    category VARCHAR(50) DEFAULT NULL,
    min_price NUMERIC(10, 2) DEFAULT 0,
    max_price NUMERIC(10, 2) DEFAULT 9999999.99
)
RETURNS TABLE (
    product_id INTEGER,
    name VARCHAR(200),
    category VARCHAR(50),
    price NUMERIC(10, 2),
    description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        id, name, category, price, description
    FROM products
    WHERE (name ILIKE '%search_term%' OR description ILIKE '%search_term%')
      AND (category IS NULL OR category = search_products.category)
      AND price BETWEEN min_price AND max_price;
END;
$$
LANGUAGE plpgsql;

-- Call the function with different parameters
SELECT * FROM search_products('laptop', 'electronics', 500, 1500);
SELECT * FROM search_products('phone');
```

### 3. Functions with Dynamic SQL

#### Example: Dynamic Query Building
```sql
-- Function to generate dynamic reports
CREATE OR REPLACE FUNCTION generate_report(
    report_type VARCHAR(20),
    start_date DATE,
    end_date DATE
)
RETURNS TABLE (
    report_date DATE,
    metric_name VARCHAR(50),
    metric_value NUMERIC
) AS $$
DECLARE
    query TEXT;
BEGIN
    -- Build dynamic query based on report type
    CASE report_type
        WHEN 'sales' THEN
            query := 'SELECT order_date, ''total_sales'', SUM(amount) 
                     FROM orders 
                     WHERE order_date BETWEEN $1 AND $2 
                     GROUP BY order_date';
        WHEN 'customers' THEN
            query := 'SELECT created_at, ''new_customers'', COUNT(*) 
                     FROM customers 
                     WHERE created_at BETWEEN $1 AND $2 
                     GROUP BY created_at';
        ELSE
            RAISE EXCEPTION 'Unknown report type: %', report_type;
    END CASE;
    
    -- Execute dynamic query
    RETURN QUERY EXECUTE query
    USING start_date, end_date;
END;
$$
LANGUAGE plpgsql;

-- Call the function
SELECT * FROM generate_report('sales', '2024-01-01', '2024-01-31');
```

## Error Handling

### 1. Basic Exception Handling

#### Example: Simple Error Handling
```sql
-- Function with basic exception handling
CREATE OR REPLACE FUNCTION safe_divide(
    numerator NUMERIC,
    denominator NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
    result NUMERIC;
BEGIN
    -- Check for division by zero
    IF denominator = 0 THEN
        RAISE EXCEPTION 'Division by zero is not allowed';
    END IF;
    
    result := numerator / denominator;
    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error occurred: %', SQLERRM;
        RETURN NULL;
END;
$$
LANGUAGE plpgsql;

-- Call the function
SELECT safe_divide(10, 2);
SELECT safe_divide(10, 0);
```

#### Example: Specific Exception Handling
```sql
-- Function with specific exception handling
CREATE OR REPLACE FUNCTION update_user_email(
    user_id INTEGER,
    new_email VARCHAR(255)
)
RETURNS BOOLEAN AS $$
DECLARE
    email_count INTEGER;
BEGIN
    -- Check if email already exists
    SELECT COUNT(*) 
    INTO email_count
    FROM users 
    WHERE email = new_email AND id != user_id;
    
    IF email_count > 0 THEN
        RAISE EXCEPTION 'Email already exists: %', new_email;
    END IF;
    
    -- Update email
    UPDATE users 
    SET email = new_email, updated_at = NOW()
    WHERE id = update_user_email.user_id;
    
    RETURN FOUND;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Email already exists: %', new_email;
        RETURN false;
    WHEN others THEN
        RAISE NOTICE 'Error updating email: %', SQLERRM;
        RETURN false;
END;
$$
LANGUAGE plpgsql;

-- Call the function
SELECT update_user_email(123, 'newemail@example.com');
```

### 2. Custom Exception Handling

#### Example: Custom Exception
```sql
-- Function with custom exception
CREATE OR REPLACE FUNCTION process_order(
    order_id INTEGER
)
RETURNS VARCHAR AS $$
DECLARE
    order_status VARCHAR(20);
    insufficient_funds EXCEPTION;
    invalid_items EXCEPTION;
BEGIN
    -- Check order status
    SELECT status INTO order_status FROM orders WHERE id = process_order.order_id;
    
    IF order_status = 'cancelled' THEN
        RAISE NOTICE 'Order is already cancelled: %', order_id;
        RETURN 'cancelled';
    END IF;
    
    -- Check inventory
    IF EXISTS (
        SELECT 1 FROM order_items oi
        INNER JOIN products p ON oi.product_id = p.id
        WHERE oi.order_id = process_order.order_id
        AND oi.quantity > p.stock
    ) THEN
        RAISE insufficient_funds;
    END IF;
    
    -- Process payment
    IF NOT process_payment(order_id) THEN
        RAISE insufficient_funds;
    END IF;
    
    -- Update order status
    UPDATE orders SET status = 'completed' WHERE id = process_order.order_id;
    RETURN 'completed';
    
EXCEPTION
    WHEN insufficient_funds THEN
        UPDATE orders SET status = 'failed' WHERE id = process_order.order_id;
        RETURN 'failed';
    WHEN invalid_items THEN
        UPDATE orders SET status = 'invalid' WHERE id = process_order.order_id;
        RETURN 'invalid';
    WHEN others THEN
        UPDATE orders SET status = 'error' WHERE id = process_order.order_id;
        RAISE NOTICE 'Error processing order: %', SQLERRM;
        RETURN 'error';
END;
$$
LANGUAGE plpgsql;

-- Call the function
SELECT process_order(123);
```

### 3. Transaction Control

#### Example: Transaction Management
```sql
-- Function with transaction control
CREATE OR REPLACE FUNCTION transfer_funds(
    from_account_id INTEGER,
    to_account_id INTEGER,
    amount NUMERIC(12, 2)
)
RETURNS BOOLEAN AS $$
DECLARE
    from_balance NUMERIC(12, 2);
    to_balance NUMERIC(12, 2);
BEGIN
    -- Start transaction
    PERFORM pg_advisory_xact_lock(from_account_id);
    PERFORM pg_advisory_xact_lock(to_account_id);
    
    -- Check balances
    SELECT balance INTO from_balance FROM accounts WHERE id = from_account_id;
    SELECT balance INTO to_balance FROM accounts WHERE id = to_account_id;
    
    -- Validate transfer
    IF from_balance < amount THEN
        RAISE EXCEPTION 'Insufficient funds';
    END IF;
    
    -- Perform transfer
    UPDATE accounts SET balance = balance - amount WHERE id = from_account_id;
    UPDATE accounts SET balance = balance + amount WHERE id = to_account_id;
    
    -- Log transaction
    INSERT INTO transactions (from_account_id, to_account_id, amount, created_at)
    VALUES (from_account_id, to_account_id, amount, NOW());
    
    RETURN true;
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Transaction failed: %', SQLERRM;
        RETURN false;
END;
$$
LANGUAGE plpgsql;

-- Call the function
SELECT transfer_funds(1, 2, 100.00);
```

## Performance Optimization

### 1. Function Optimization

#### IMMUTABLE Functions
```sql
-- Create immutable function for deterministic results
CREATE OR REPLACE FUNCTION calculate_tax(
    amount NUMERIC(10, 2),
    tax_rate NUMERIC(5, 4)
)
RETURNS NUMERIC(12, 2) IMMUTABLE AS $$
BEGIN
    RETURN amount * tax_rate;
END;
$$
LANGUAGE plpgsql;

-- Create index using function
CREATE INDEX idx_orders_tax_amount ON orders(calculate_tax(total_amount, 0.0875));
```

#### STABLE Functions
```sql
-- Create stable function for consistent results within transaction
CREATE OR REPLACE FUNCTION get_current_exchange_rate(
    currency_code VARCHAR(3)
)
RETURNS NUMERIC(8, 4) STABLE AS $$
BEGIN
    RETURN (SELECT rate FROM exchange_rates WHERE currency = currency_code);
END;
$$
LANGUAGE plpgsql;
```

#### VOLATILE Functions
```sql
-- Create volatile function for non-deterministic results
CREATE OR REPLACE FUNCTION generate_random_order_id()
RETURNS INTEGER VOLATILE AS $$
BEGIN
    RETURN FLOOR(RANDOM() * 1000000);
END;
$$
LANGUAGE plpgsql;
```

### 2. Performance Considerations

#### Function Caching
```sql
-- Use SQL functions for simple operations
CREATE OR REPLACE FUNCTION add_numbers(
    a INTEGER,
    b INTEGER
)
RETURNS INTEGER AS $$
    SELECT $1 + $2;
$$
LANGUAGE sql IMMUTABLE;

-- Use PL/pgSQL for complex logic
CREATE OR REPLACE FUNCTION complex_calculation(
    input_value NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
    result NUMERIC;
BEGIN
    -- Complex calculations with multiple steps
    result := input_value * 1.1;
    result := result - 5.0;
    result := result * 1.05;
    RETURN result;
END;
$$
LANGUAGE plpgsql;
```

#### Parameter Optimization
```sql
-- Use default parameters to reduce function calls
CREATE OR REPLACE FUNCTION search_products(
    search_term VARCHAR(100),
    category VARCHAR(50) DEFAULT NULL,
    min_price NUMERIC(10, 2) DEFAULT 0,
    max_price NUMERIC(10, 2) DEFAULT 9999999.99
)
RETURNS TABLE (
    product_id INTEGER,
    name VARCHAR(200),
    category VARCHAR(50),
    price NUMERIC(10, 2),
    description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        id, name, category, price, description
    FROM products
    WHERE (name ILIKE '%search_term%' OR description ILIKE '%search_term%')
      AND (category IS NULL OR category = search_products.category)
      AND price BETWEEN min_price AND max_price;
END;
$$
LANGUAGE plpgsql;
```

## Security Considerations

### 1. Security Definer Functions

#### Example: Security Definer
```sql
-- Create function that runs with definer privileges
CREATE OR REPLACE FUNCTION create_order(
    customer_id INTEGER,
    product_id INTEGER,
    quantity INTEGER
)
RETURNS INTEGER SECURITY DEFINER AS $$
DECLARE
    order_id INTEGER;
BEGIN
    -- This function runs with the privileges of the creator
    INSERT INTO orders (customer_id, status, created_at)
    VALUES (customer_id, 'pending', NOW())
    RETURNING id INTO order_id;
    
    INSERT INTO order_items (order_id, product_id, quantity, price)
    SELECT order_id, product_id, quantity, price
    FROM products WHERE id = create_order.product_id;
    
    RETURN order_id;
END;
$$
LANGUAGE plpgsql;

-- Grant execute permission to specific role
GRANT EXECUTE ON FUNCTION create_order(INTEGER, INTEGER, INTEGER) TO app_user;
```

### 2. Input Validation

#### Example: Input Validation
```sql
-- Function with input validation
CREATE OR REPLACE FUNCTION update_user_profile(
    user_id INTEGER,
    new_email VARCHAR(255),
    new_phone VARCHAR(20)
)
RETURNS BOOLEAN AS $$
DECLARE
    email_pattern VARCHAR(100) := '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
    phone_pattern VARCHAR(100) := '^\+?[1-9]\d{1,14}$';
BEGIN
    -- Validate email format
    IF new_email IS NOT NULL AND new_email !~ email_pattern THEN
        RAISE EXCEPTION 'Invalid email format: %', new_email;
    END IF;
    
    -- Validate phone format
    IF new_phone IS NOT NULL AND new_phone !~ phone_pattern THEN
        RAISE EXCEPTION 'Invalid phone format: %', new_phone;
    END IF;
    
    -- Update profile
    UPDATE users 
    SET email = COALESCE(new_email, email),
        phone = COALESCE(new_phone, phone),
        updated_at = NOW()
    WHERE id = update_user_profile.user_id;
    
    RETURN FOUND;
END;
$$
LANGUAGE plpgsql;
```

## Best Practices

### 1. Function Design

#### Naming Conventions
```sql
-- Use descriptive names
CREATE OR REPLACE FUNCTION calculate_order_total(...);
CREATE OR REPLACE FUNCTION get_user_by_email(...);
CREATE OR REPLACE FUNCTION update_product_stock(...);

-- Avoid abbreviations
-- Good: get_customer_order_count
-- Bad: get_cust_ord_cnt
```

#### Documentation
```sql
-- Document functions with comments
CREATE OR REPLACE FUNCTION calculate_order_total(
    order_id INTEGER
)
RETURNS NUMERIC(12, 2) AS $$
/*
 * Calculates the total amount for an order including tax
 * 
 * Parameters:
 *   order_id - ID of the order to calculate
 * 
 * Returns:
 *   Total amount including tax
 * 
 * Notes:
 *   - Includes 8.75% tax
 *   - Handles NULL values gracefully
 */
BEGIN
    -- Function implementation
END;
$$
LANGUAGE plpgsql;
```

### 2. Testing Functions

#### Unit Testing
```sql
-- Test functions with different inputs
SELECT calculate_order_total(123); -- Valid order
SELECT calculate_order_total(999999); -- Non-existent order
SELECT calculate_order_total(NULL); -- NULL input

-- Test edge cases
SELECT calculate_order_total(0); -- Zero quantity
SELECT calculate_order_total(-1); -- Negative quantity
```

#### Performance Testing
```sql
-- Test function performance
	EXPLAIN ANALYZE SELECT calculate_order_total(123);
	
-- Test with large datasets
SELECT calculate_order_total(id) FROM orders WHERE created_at > '2024-01-01' LIMIT 1000;
```

### 3. Maintenance

#### Function Maintenance
```sql
-- Update functions as needed
CREATE OR REPLACE FUNCTION calculate_order_total(
    order_id INTEGER
)
RETURNS NUMERIC(12, 2) AS $$
-- Updated implementation with new tax rules
BEGIN
    -- New logic
END;
$$
LANGUAGE plpgsql;

-- Drop unused functions
DROP FUNCTION IF EXISTS old_function_name(...);
```

## Common Patterns

### 1. Data Validation
```sql
-- Function to validate data before insert/update
CREATE OR REPLACE FUNCTION validate_user_data(
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(255)
)
RETURNS BOOLEAN AS $$
BEGIN
    IF first_name IS NULL OR LENGTH(TRIM(first_name)) = 0 THEN
        RAISE EXCEPTION 'First name is required';
    END IF;
    
    IF last_name IS NULL OR LENGTH(TRIM(last_name)) = 0 THEN
        RAISE EXCEPTION 'Last name is required';
    END IF;
    
    IF email IS NULL OR email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format';
    END IF;
    
    RETURN true;
END;
$$
LANGUAGE plpgsql;
```

### 2. Audit Logging
```sql
-- Function to log changes
CREATE OR REPLACE FUNCTION log_data_change()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log (table_name, record_id, old_data, new_data, changed_by, change_time)
    VALUES (
        TG_TABLE_NAME,
        NEW.id,
        row_to_json(OLD),
        row_to_json(NEW),
        current_user,
        NOW()
    );
    
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER audit_users_change
AFTER UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION log_data_change();
```

### 3. Data Aggregation
```sql
-- Function to generate reports
CREATE OR REPLACE FUNCTION generate_sales_report(
    start_date DATE,
    end_date DATE
)
RETURNS TABLE (
    date DATE,
    total_sales NUMERIC(12, 2),
    order_count INTEGER,
    avg_order_value NUMERIC(12, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        order_date,
        SUM(amount) AS total_sales,
        COUNT(*) AS order_count,
        AVG(amount) AS avg_order_value
    FROM orders
    WHERE order_date BETWEEN start_date AND end_date
    GROUP BY order_date
    ORDER BY order_date;
END;
$$
LANGUAGE plpgsql;
```

## Conclusion
PL/pgSQL stored procedures are a powerful feature of PostgreSQL that allow you to encapsulate complex business logic, improve performance, and maintain data integrity. By following the best practices outlined in this guide and understanding the advanced features available, you can create efficient, secure, and maintainable stored procedures that enhance your database applications.

Remember to:
- Choose the appropriate function volatility (IMMUTABLE, STABLE, VOLATILE)
- Use proper error handling with exceptions
- Validate all input parameters
- Consider security implications with SECURITY DEFINER
- Test functions thoroughly with different inputs
- Monitor function performance with EXPLAIN ANALYZE
- Document functions with clear comments
- Follow consistent naming conventions
- Use appropriate function types for different use cases

With proper implementation of PL/pgSQL functions, you can create robust database applications that are both efficient and maintainable.