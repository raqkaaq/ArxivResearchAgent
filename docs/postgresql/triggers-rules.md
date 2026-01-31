# PostgreSQL Triggers and Rules Guide

## Overview
This comprehensive guide covers PostgreSQL triggers and rules, including creation, management, performance considerations, and best practices for implementing automated database behaviors.

## Table of Contents
1. [Triggers](#triggers)
2. [Rules](#rules)
3. [Performance Considerations](#performance-considerations)
4. [Best Practices](#best-practices)
5. [Common Patterns](#common-patterns)

## Triggers

### 1. Trigger Basics

#### Trigger Syntax
```sql
-- Basic trigger structure
CREATE OR REPLACE FUNCTION trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    -- Trigger logic
    RETURN NEW; -- or OLD, or NULL
END;
$$
LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER trigger_name
{BEFORE | AFTER | INSTEAD OF} {INSERT | UPDATE | DELETE | TRUNCATE}
    ON table_name
    [FOR [EACH] {ROW | STATEMENT}]
    [WHEN (condition)]
    EXECUTE FUNCTION trigger_function();
```

#### Trigger Timing
- **BEFORE**: Trigger fires before the operation is executed
- **AFTER**: Trigger fires after the operation is executed
- **INSTEAD OF**: Trigger replaces the operation entirely

#### Trigger Scope
- **ROW**: Trigger fires once for each affected row
- **STATEMENT**: Trigger fires once per SQL statement

### 2. Row-Level Triggers

#### Example: Audit Logging
```sql
-- Audit log table
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(50),
    record_id INTEGER,
    operation VARCHAR(10),
    old_data JSONB,
    new_data JSONB,
    changed_by VARCHAR(50),
    change_time TIMESTAMP DEFAULT NOW()
);

-- Audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log (table_name, record_id, operation, old_data, new_data, changed_by)
    VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        TG_OP,
        row_to_json(OLD),
        row_to_json(NEW),
        current_user
    );
    
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

-- Create audit triggers
CREATE TRIGGER audit_users_insert
AFTER INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_users_update
AFTER UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_users_delete
AFTER DELETE ON users
FOR EACH ROW
EXECUTE FUNCTION audit_trigger_function();
```

#### Example: Data Validation
```sql
-- Trigger to validate email format
CREATE OR REPLACE FUNCTION validate_email_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.email IS NOT NULL AND NEW.email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format: %', NEW.email;
    END IF;
    
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

-- Create validation trigger
CREATE TRIGGER validate_users_email
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION validate_email_trigger();
```

#### Example: Timestamp Management
```sql
-- Trigger to manage timestamps
CREATE OR REPLACE FUNCTION manage_timestamps()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.created_at := NOW();
        NEW.updated_at := NOW();
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.updated_at := NOW();
        NEW.created_at := OLD.created_at; -- Preserve original creation time
    END IF;
    
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

-- Create timestamp trigger
CREATE TRIGGER manage_users_timestamps
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION manage_timestamps();
```

### 3. Statement-Level Triggers

#### Example: Logging
```sql
-- Statement-level logging trigger
CREATE OR REPLACE FUNCTION log_statement_trigger()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO statement_log (table_name, operation, row_count, executed_by, execution_time)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        CASE TG_LEVEL WHEN 'ROW' THEN 1 WHEN 'STATEMENT' THEN pg_trigger_depth() END,
        current_user,
        NOW()
    );
    
    RETURN NULL; -- Statement-level triggers return NULL
END;
$$
LANGUAGE plpgsql;

-- Create statement-level trigger
CREATE TRIGGER log_users_statement
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH STATEMENT
EXECUTE FUNCTION log_statement_trigger();
```

#### Example: Complex Business Logic
```sql
-- Trigger for order processing
CREATE OR REPLACE FUNCTION process_order_trigger()
RETURNS TRIGGER AS $$
DECLARE
    total_amount NUMERIC(12, 2);
    stock_available INTEGER;
BEGIN
    -- Calculate order total
    SELECT SUM(oi.quantity * p.price)
    INTO total_amount
    FROM order_items oi
    INNER JOIN products p ON oi.product_id = p.id
    WHERE oi.order_id = NEW.id;
    
    -- Check inventory
    FOR item IN 
        SELECT oi.product_id, oi.quantity, p.stock
        FROM order_items oi
        INNER JOIN products p ON oi.product_id = p.id
        WHERE oi.order_id = NEW.id
    LOOP
        IF item.quantity > item.stock THEN
            RAISE EXCEPTION 'Insufficient stock for product %: requested %, available %',
                item.product_id, item.quantity, item.stock;
        END IF;
    END LOOP;
    
    -- Update order total
    UPDATE orders SET total_amount = total_amount WHERE id = NEW.id;
    
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

-- Create order processing trigger
CREATE TRIGGER process_orders
AFTER INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION process_order_trigger();
```

### 4. INSTEAD OF Triggers

#### Example: View Modification
```sql
-- Create a view with INSTEAD OF trigger
CREATE VIEW active_users_view AS
SELECT id, name, email, status
FROM users
WHERE status = 'active';

-- INSTEAD OF trigger for view updates
CREATE OR REPLACE FUNCTION active_users_view_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO users (name, email, status)
        VALUES (NEW.name, NEW.email, 'active');
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        UPDATE users 
        SET name = NEW.name, email = NEW.email
        WHERE id = OLD.id;
        RETURN NEW;
    ELSIF TG_OP = ɽELETE' THEN
        UPDATE users SET status = 'inactive' WHERE id = OLD.id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

-- Create INSTEAD OF trigger
CREATE TRIGGER active_users_view_modify
INSTEAD OF INSERT OR UPDATE OR DELETE ON active_users_view
FOR EACH ROW
EXECUTE FUNCTION active_users_view_trigger();
```

## Rules

### 1. Rule Basics

#### Rule Syntax
```sql
-- Basic rule structure
CREATE [OR REPLACE] RULE rule_name AS ON {SELECT | INSERT | UPDATE | DELETE}
    TO table_name
    [WHERE condition]
    DO [INSTEAD] [NOTHING | command | (command_list)];
```

#### Rule Types
- **DO INSTEAD**: Replaces the original command
- **DO ALSO**: Executes in addition to the original command
- **DO NOTHING**: Suppresses the original command

### 2. DO INSTEAD Rules

#### Example: Automatic Archiving
```sql
-- Create archive table
CREATE TABLE users_archive (
    LIKE users INCLUDING ALL,
    archived_at TIMESTAMP DEFAULT NOW()
);

-- Create archiving rule
CREATE RULE archive_users_instead AS ON DELETE TO users
DO INSTEAD (
    INSERT INTO users_archive (id, name, email, status, created_at, updated_at)
    SELECT id, name, email, status, created_at, updated_at
    FROM OLD;
);

-- Test the rule
DELETE FROM users WHERE id = 123; -- This will archive instead of delete
```

#### Example: Data Transformation
```sql
-- Create transformation rule
CREATE RULE transform_data AS ON INSERT TO raw_data
DO INSTEAD (
    INSERT INTO processed_data (sensor_id, reading_value, reading_time, processed_at)
    SELECT 
        sensor_id,
        reading_value * 1.1, -- Apply calibration
        reading_time,
        NOW()
    FROM NEW;
);

-- Test the rule
INSERT INTO raw_data (sensor_id, reading_value, reading_time)
VALUES (1, 100.0, NOW()); -- This will transform and insert into processed_data
```

### 3. DO ALSO Rules

#### Example: Cascade Updates
```sql
-- Create cascade update rule
CREATE RULE cascade_user_update AS ON UPDATE TO users
DO ALSO (
    UPDATE orders SET customer_name = NEW.name 
    WHERE customer_id = NEW.id AND customer_name != NEW.name;
    
    UPDATE subscriptions SET subscriber_name = NEW.name 
    WHERE subscriber_id = NEW.id AND subscriber_name != NEW.name;
);

-- Test the rule
UPDATE users SET name = 'New Name' WHERE id = 123; -- This will also update related tables
```

#### Example: Logging with Original Action
```sql
-- Create logging rule
CREATE RULE log_user_changes AS ON UPDATE TO users
DO ALSO (
    INSERT INTO user_changes_log (user_id, old_name, new_name, change_time)
    VALUES (OLD.id, OLD.name, NEW.name, NOW())
);

-- Test the rule
UPDATE users SET name = 'Updated Name' WHERE id = 123; -- This will log the change and perform update
```

### 4. DO NOTHING Rules

#### Example: Access Control
```sql
-- Create access control rule
CREATE RULE deny_inactive_updates AS ON UPDATE TO users
WHERE OLD.status = 'inactive'
DO NOTHING;

-- Test the rule
UPDATE users SET email = 'newemail@example.com' WHERE status = 'inactive'; -- This will be denied
```

#### Example: Data Validation
```sql
-- Create validation rule
CREATE RULE validate_order_amount AS ON INSERT TO orders
WHERE NEW.amount < 0
DO NOTHING;

-- Test the rule
INSERT INTO orders (amount, customer_id) VALUES (-100.0, 123); -- This will be denied
```

## Performance Considerations

### 1. Trigger Performance

#### Trigger Overhead
```sql
-- Monitor trigger performance
EXPLAIN ANALYZE INSERT INTO users (name, email) VALUES ('John Doe', 'john@example.com');

-- Check trigger execution time
SELECT 
    tg_name,
    tgrelid::regclass AS table_name,
    tgtype,
    tgenabled
FROM pg_trigger
WHERE tgenabled = 'O'; -- Enabled triggers
```

#### Performance Optimization
```sql
-- Use statement-level triggers when possible
-- Row-level triggers have more overhead

-- Avoid complex logic in triggers
-- Move complex operations to functions
-- Use indexes in trigger functions

-- Consider disabling triggers during bulk operations
ALTER TABLE users DISABLE TRIGGER ALL;
-- Perform bulk operations
ALTER TABLE users ENABLE TRIGGER ALL;
```

### 2. Rule Performance

#### Rule Execution
```sql
-- Rules are expanded during query planning
-- Can affect query performance

-- Monitor rule usage
SELECT 
    schemaname,
    tablename,
    rulename,
    definition
FROM pg_rules
WHERE schemaname = 'public';
```

#### Rule Optimization
```sql
-- Use rules sparingly
-- Consider triggers for complex logic
-- Avoid nested rules
-- Test performance impact
```

## Best Practices

### 1. Trigger Design

#### Naming Conventions
```sql
-- Use descriptive names
CREATE TRIGGER audit_users_insert;
CREATE TRIGGER validate_email_format;
CREATE TRIGGER update_timestamps;

-- Avoid generic names
-- Bad: trigger1, t2, my_trigger
```

#### Function Design
```sql
-- Create reusable trigger functions
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    -- Generic audit logic
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

-- Use specific trigger names for different tables
CREATE TRIGGER audit_users_insert ON users...;
CREATE TRIGGER audit_orders_insert ON orders...;
```

### 2. Error Handling

#### Exception Handling in Triggers
```sql
-- Handle exceptions in trigger functions
CREATE OR REPLACE FUNCTION safe_update_trigger()
RETURNS TRIGGER AS $$
BEGIN
    -- Trigger logic
    RETURN NEW;
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Trigger error: %', SQLERRM;
        RETURN NULL; -- Cancel operation
END;
$$
LANGUAGE plpgsql;
```

#### Transaction Control
```sql
-- Use transactions in triggers when needed
CREATE OR REPLACE FUNCTION transfer_funds_trigger()
RETURNS TRIGGER AS $$
BEGIN
    -- Start transaction
    PERFORM pg_advisory_xact_lock(NEW.from_account_id);
    PERFORM pg_advisory_xact_lock(NEW.to_account_id);
    
    -- Transfer logic
    
    RETURN NEW;
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Transfer failed: %', SQLERRM;
        RETURN NULL;
END;
$$
LANGUAGE plpgsql;
```

### 3. Maintenance

#### Trigger Maintenance
```sql
-- List all triggers
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing,
    action_orientation,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public';

-- Disable triggers
ALTER TABLE users DISABLE TRIGGER ALL;

-- Enable triggers
ALTER TABLE users ENABLE TRIGGER ALL;

-- Drop triggers
DROP TRIGGER IF EXISTS audit_users_insert ON users;
```

#### Rule Maintenance
```sql
-- List all rules
SELECT 
    schemaname,
    tablename,
    rulename,
    definition
FROM pg_rules
WHERE schemaname = 'public';

-- Drop rules
DROP RULE IF EXISTS archive_users_instead ON users;
```

## Common Patterns

### 1. Data Synchronization
```sql
-- Synchronize data between tables
CREATE OR REPLACE FUNCTION sync_user_data()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        INSERT INTO user_sync (user_id, sync_data, sync_time)
        VALUES (NEW.id, row_to_json(NEW), NOW())
        ON CONFLICT (user_id) 
        DO UPDATE SET sync_data = EXCLUDED.sync_data, sync_time = EXCLUDED.sync_time;
    ELSIF TG_OP = 'DELETE' THEN
        DELETE FROM user_sync WHERE user_id = OLD.id;
    END IF;
    
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

-- Create synchronization trigger
CREATE TRIGGER sync_users
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW
EXECUTE FUNCTION sync_user_data();
```

### 2. Data Validation
```sql
-- Complex data validation
CREATE OR REPLACE FUNCTION validate_order_data()
RETURNS TRIGGER AS $$
BEGIN
    -- Check for valid customer
    IF NOT EXISTS (SELECT 1 FROM customers WHERE id = NEW.customer_id) THEN
        RAISE EXCEPTION 'Invalid customer ID: %', NEW.customer_id;
    END IF;
    
    -- Check for valid products
    IF EXISTS (
        SELECT 1 FROM order_items oi
        LEFT JOIN products p ON oi.product_id = p.id
        WHERE oi.order_id = NEW.id AND p.id IS NULL
    ) THEN
        RAISE EXCEPTION 'Order contains invalid products';
    END IF;
    
    -- Check for minimum order amount
    IF NEW.amount < 10.00 THEN
        RAISE EXCEPTION 'Minimum order amount is $10.00';
    END IF;
    
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

-- Create validation trigger
CREATE TRIGGER validate_orders
BEFORE INSERT OR UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION validate_order_data();
```

### 3. Business Logic Automation
```sql
-- Automated business logic
CREATE OR REPLACE FUNCTION apply_discounts()
RETURNS TRIGGER AS $$
DECLARE
    discount_amount NUMERIC(10, 2);
BEGIN
    -- Apply bulk discount
    IF NEW.quantity >= 100 THEN
        discount_amount := NEW.total_amount * 0.10; -- 10% discount
        NEW.total_amount := NEW.total_amount - discount_amount;
        NEW.discount_applied := true;
    END IF;
    
    -- Apply loyalty discount
    IF NEW.customer_loyalty_points > 1000 THEN
        discount_amount := NEW.total_amount * 0.05; -- 5% loyalty discount
        NEW.total_amount := NEW.total_amount - discount_amount;
        NEW.loyalty_discount_applied := true;
    END IF;
    
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

-- Create discount trigger
CREATE TRIGGER apply_order_discounts
BEFORE INSERT OR UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION apply_discounts();
```

## Security Considerations

### 1. Security Definer Triggers
```sql
-- Security definer trigger
CREATE OR REPLACE FUNCTION secure_data_access()
RETURNS TRIGGER SECURITY DEFINER AS $$
BEGIN
    -- This function runs with the privileges of the creator
    -- Implement security checks
    IF current_user != 'admin_user' THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION secure_data_access() TO app_user;
```

### 2. Input Validation
```sql
-- Input validation in triggers
CREATE OR REPLACE FUNCTION validate_sensitive_data()
RETURNS TRIGGER AS $$
BEGIN
    -- Sanitize input
    NEW.sensitive_data := regexp_replace(NEW.sensitive_data, '[^'\w\s@.-]', '', 'g');
    
    -- Check for SQL injection patterns
    IF NEW.input_data ~* '(SELECT|INSERT|UPDATE|DELETE|DROP|ALTER)' THEN
        RAISE EXCEPTION 'Potential SQL injection detected';
    END IF;
    
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;
```

## Conclusion
Triggers and rules are powerful features in PostgreSQL that allow you to automate database behaviors and enforce business rules. By understanding the differences between triggers and rules, following best practices, and considering performance implications, you can create efficient and maintainable database automation.

Remember to:
- Use triggers for complex row-level operations
- Use rules for simple query transformations
- Consider performance implications
- Implement proper error handling
- Follow consistent naming conventions
- Test thoroughly with different scenarios
- Monitor trigger and rule performance
- Document all automation logic
- Consider security implications
- Maintain and update as business requirements change

With proper implementation of triggers and rules, you can create robust database applications that automatically enforce business rules and maintain data integrity without requiring application-level logic.