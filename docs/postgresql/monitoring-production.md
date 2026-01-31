# PostgreSQL Monitoring in Production Guide

## Overview
This comprehensive guide covers PostgreSQL monitoring in production environments, including system monitoring, query performance monitoring, replication monitoring, alerting, and best practices for maintaining optimal database performance.

## Table of Contents
1. [System Monitoring](#system-monitoring)
2. [Query Performance Monitoring](#query-performance-monitoring)
3. [Replication Monitoring](#replication-monitoring)
4. [Alerting and Notifications](#alerting-and-notifications)
5. [Monitoring Tools](#monitoring-tools)
6. [Best Practices](#best-practices)

## System Monitoring

### 1. Database Metrics

#### Basic Database Metrics
```sql
-- Monitor database activity
SELECT 
    datname,
    numbackends,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    tup_returned,
    tup_fetched,
    tup_inserted,
    tup_updated,
    tup_deleted
FROM pg_stat_database
WHERE datname = 'mydb';

-- Monitor database size
SELECT 
    pg_size_pretty(pg_database_size(CURRENT_DATABASE())) AS database_size,
    pg_size_pretty(pg_total_relation_size('public.users')) AS users_table_size,
    pg_size_pretty(pg_total_relation_size('public.orders')) AS orders_table_size;

-- Monitor connection usage
SELECT 
    state,
    COUNT(*) AS connection_count,
    ROUND(100.0 * COUNT(*) / (SELECT setting::integer FROM pg_settings WHERE name = 'max_connections'), 2) AS usage_percentage
FROM pg_stat_activity
GROUP BY state;
```

#### System Resource Monitoring
```sql
-- Monitor system resources
SELECT 
    now() AS current_time,
    pg_postmaster_start_time() AS postgres_start_time,
    date_trunc('second', current_timestamp - pg_postmaster_start_time()) AS uptime,
    (SELECT setting::integer FROM pg_settings WHERE name = 'max_connections') AS max_connections,
    (SELECT COUNT(*) FROM pg_stat_activity) AS current_connections,
    (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active') AS active_connections;

-- Monitor checkpoint statistics
SELECT 
    checkpoints_timed,
    checkpoints_req,
    checkpoint_write_time,
    checkpoint_sync_time,
    buffers_checkpoint,
    buffers_clean,
    maxwritten_clean
FROM pg_stat_bgwriter;
```

### 2. Performance Metrics

#### Query Performance Metrics
```sql
-- Monitor slow queries
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    shared_blks_hit,
    shared_blks_read,
    shared_blks_dirtied,
    shared_blks_written,
    temp_blks_read,
    temp_blks_written,
    blk_read_time,
    blk_write_time
FROM pg_stat_statements
WHERE mean_time > 1000  -- More than 1 second
ORDER BY total_time DESC
LIMIT 10;

-- Monitor query patterns
SELECT 
    substring(query from 10 for 100) AS short_query,
    calls,
    total_time,
    mean_time,
    rows,
    shared_blks_hit,
    shared_blks_read
FROM pg_stat_statements
WHERE query LIKE '%SELECT%FROM users%'
ORDER BY total_time DESC
LIMIT 5;
```

#### Index Usage Metrics
```sql
-- Monitor index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan AS scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan > 0
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

## Query Performance Monitoring

### 1. Query Analysis

#### EXPLAIN ANALYZE
```sql
-- Analyze query execution plan
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'john@example.com';

-- Detailed analysis
EXPLAIN (VERBOSE, ANALYZE, BUFFERS) 
SELECT u.name, o.order_id, o.total_amount
FROM users u
INNER JOIN orders o ON u.id = o.user_id
WHERE u.status = 'active'
ORDER BY o.order_date DESC
LIMIT 10;
```

#### Query Statistics
```sql
-- Check query statistics
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    shared_blks_hit,
    shared_blks_read,
    shared_blks_dirtied,
    shared_blks_written,
    temp_blks_read,
    temp_blks_written,
    blk_read_time,
    blk_write_time
FROM pg_stat_statements
WHERE query LIKE '%SELECT%FROM orders%'
ORDER BY total_time DESC
LIMIT 10;
```

### 2. Performance Trends

#### Long-term Performance
```sql
-- Monitor performance trends
SELECT 
    date_trunc('hour', query_start) AS hour,
    COUNT(*) AS query_count,
    AVG(mean_time) AS avg_query_time,
    MAX(mean_time) AS max_query_time
FROM pg_stat_statements
WHERE query_start > NOW() - INTERVAL '1 day'
GROUP BY date_trunc('hour', query_start)
ORDER BY hour;
```

#### Performance Degradation
```sql
-- Identify performance degradation
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    shared_blks_hit,
    shared_blks_read,
    CASE 
        WHEN shared_blks_hit + shared_blks_read > 0 
        THEN ROUND(100.0 * shared_blks_hit / (shared_blks_hit + shared_blks_read), 2)
        ELSE 0
    END AS cache_hit_ratio
FROM pg_stat_statements
WHERE mean_time > 1000  -- More than 1 second
ORDER BY total_time DESC
LIMIT 10;
```

## Replication Monitoring

### 1. Primary Server Monitoring

#### Replication Status
```sql
-- Check replication status
SELECT 
    client_addr,
    usename,
    application_name,
    backend_start,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    sync_state,
    EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS replication_lag_seconds
FROM pg_stat_replication;

-- Check replication slots
SELECT * FROM pg_replication_slots;
```

#### Replication Performance
```sql
-- Monitor replication throughput
SELECT 
    client_addr,
    usename,
    application_name,
    (sent_lsn - write_lsn) * 512 AS sent_lag_bytes,
    (write_lsn - flush_lsn) * 512 AS write_lag_bytes,
    (flush_lsn - replay_lsn) * 512 AS flush_lag_bytes
FROM pg_stat_replication;
```

### 2. Standby Server Monitoring

#### Standby Status
```sql
-- Check standby status
SELECT 
    status,
    receive_start_lsn,
    receive_start_tli,
    received_lsn,
    received_tli,
    last_msg_send_time,
    last_msg_receipt_time,
    latest_end_lsn,
    latest_end_time,
    slot_name
FROM pg_stat_wal_receiver;

-- Check replication slots on standby
SELECT * FROM pg_replication_slots;
```

#### Standby Performance
```sql
-- Monitor standby performance
SELECT 
    pg_is_in_recovery() AS in_recovery,
    pg_last_xact_replay_timestamp() AS last_replay_time,
    pg_last_wal_receive_lsn() AS last_receive_lsn,
    pg_last_wal_replay_lsn() AS last_replay_lsn,
    EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS replay_lag_seconds;
```

## Alerting and Notifications

### 1. Alert Configuration

#### Performance Alerts
```sql
-- Slow query alert
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
WHERE mean_time > 1000  -- More than 1 second
ORDER BY total_time DESC
LIMIT 10;

-- High connection usage alert
SELECT 
    datname,
    numbackends,
    max_connections,
    (numbackends::float / max_connections) * 100 AS connection_usage
FROM pg_stat_database
WHERE (numbackends::float / max_connections) * 100 > 80; -- Alert if usage exceeds 80%
```

#### Replication Alerts
```sql
-- Replication lag alert
SELECT 
    client_addr,
    usename,
    application_name,
    EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS lag_seconds
FROM pg_stat_replication
WHERE lag_seconds > 60; -- Alert if lag exceeds 60 seconds

-- Replication slot full alert
SELECT 
    slot_name,
    slot_type,
    database,
    active,
    active_pid,
    xmin,
    catalog_xmin,
    restart_lsn,
    confirmed_flush_lsn
FROM pg_replication_slots
WHERE active = false AND restart_lsn IS NOT NULL;
```

### 2. Alert Thresholds

#### System Alerts
```sql
-- High CPU usage alert
SELECT 
    datname,
    numbackends,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    tup_returned,
    tup_fetched,
    tup_inserted,
    tup_updated,
    tup_deleted
FROM pg_stat_database
WHERE datname = 'mydb';

-- High disk usage alert
SELECT 
    pg_size_pretty(pg_database_size(CURRENT_DATABASE())) AS database_size,
    pg_size_pretty(pg_total_relation_size('public.users')) AS users_table_size;
```

#### Performance Alerts
```sql
-- Cache hit ratio alert
SELECT 
    blks_hit,
    blks_read,
    CASE 
        WHEN blks_hit + blks_read > 0 
        THEN ROUND(100.0 * blks_hit / (blks_hit + blks_read), 2)
        ELSE 0
    END AS cache_hit_ratio
FROM pg_stat_database
WHERE datname = 'mydb' AND cache_hit_ratio < 95; -- Alert if cache hit ratio < 95%
```

## Monitoring Tools

### 1. Built-in Tools

#### pg_stat_statements
```sql
-- Enable pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Configure in postgresql.conf
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.track_utility = on
pg_stat_statements.save = on

-- Query statistics
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    shared_blks_hit,
    shared_blks_read
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;
```

#### pg_stat_activity
```sql
-- Monitor active connections
SELECT 
    pid,
    datname,
    usename,
    application_name,
    client_addr,
    backend_start,
    xact_start,
    query_start,
    state,
    wait_event,
    query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY query_start;
```

#### pg_stat_user_tables
```sql
-- Monitor table activity
SELECT 
    schemaname,
    tablename,
    n_tup_ins AS inserts,
    n_tup_upd AS updates,
    n_tup_del AS deletes,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_tup_ins + n_tup_upd + n_tup_del DESC;
```

### 2. External Tools

#### Prometheus and Grafana
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'postgres'
    static_configs:
      - targets: ['localhost:9187']
    metrics_path: '/metrics'
    scrape_interval: 30s
    scrape_timeout: 10s
```

#### Grafana Dashboard
```json
{
  "dashboard": {
    "title": "PostgreSQL Production Monitoring",
    "panels": [
      {
        "title": "Database Overview",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends",
            "legendFormat": "Active Connections"
          }
        ]
      },
      {
        "title": "Query Performance",
        "targets": [
          {
            "expr": "pg_stat_statements_mean_time",
            "legendFormat": "Mean Query Time"
          }
        ]
      }
    ]
  }
}
```

#### pgBadger
```bash
# Generate pgBadger report
pgbadger /var/log/postgresql/postgresql-15-main.log -o /var/www/html/pgbadger.html

# Set up daily reports
0 2 * * * /usr/bin/pgbadger /var/log/postgresql/postgresql-15-main.log -o /var/www/html/pgbadger_$(date +%Y%m%d).html
```

### 3. Custom Monitoring Scripts

#### Health Check Script
```bash
#!/bin/bash
# health_check.sh

# Check database connectivity
if ! pg_isready -h localhost -p 5432; then
    echo "Database is down!"
    exit 1
fi

# Check replication status
if [ $(psql -t -c "SELECT count(*) FROM pg_stat_replication WHERE state = 'streaming'") -eq 0 ]; then
    echo "No streaming replicas!"
    exit 1
fi

# Check cache hit ratio
CACHE_HIT_RATIO=$(psql -t -c "
    SELECT 
        CASE 
            WHEN blks_hit + blks_read > 0 
            THEN ROUND(100.0 * blks_hit / (blks_hit + blks_read), 2)
            ELSE 0
        END AS cache_hit_ratio
    FROM pg_stat_database
    WHERE datname = 'mydb';
")

if [ $(echo "$CACHE_HIT_RATIO < 95" | bc) -eq 1 ]; then
    echo "Cache hit ratio is low: $CACHE_HIT_RATIO%"
    exit 1
fi

echo "Database is healthy"
exit 0
```

#### Performance Alert Script
```bash
#!/bin/bash
# performance_alert.sh

# Check for slow queries
SLOW_QUERIES=$(psql -t -c "
    SELECT COUNT(*) 
    FROM pg_stat_statements 
    WHERE mean_time > 1000;
")

if [ $SLOW_QUERIES -gt 0 ]; then
    echo "Found $SLOW_QUERIES slow queries"
    # Send alert
fi

# Check replication lag
REPLICATION_LAG=$(psql -t -c "
    SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) 
    FROM pg_stat_replication 
    WHERE state = 'streaming';
")

if [ $REPLICATION_LAG -gt 60 ]; then
    echo "Replication lag is high: $REPLICATION_LAG seconds"
    # Send alert
fi
```

## Best Practices

### 1. Monitoring Strategy

#### What to Monitor
```sql
-- Key metrics to monitor
-- Database connections
-- Query performance
-- Replication status
-- System resources
-- Disk usage
-- Cache hit ratio
-- Transaction rates
-- Lock contention
-- Index usage
```

#### Monitoring Frequency
```sql
-- Real-time monitoring (every 1-5 minutes)
-- Daily monitoring (daily reports)
-- Weekly monitoring (trend analysis)
-- Monthly monitoring (capacity planning)
```

### 2. Alert Configuration

#### Critical Alerts
```sql
-- Database down
-- Replication failure
-- High connection usage
-- Low disk space
-- High CPU usage
-- Memory issues
```

#### Warning Alerts
```sql
-- Slow queries
-- High replication lag
-- Low cache hit ratio
-- Index usage issues
-- Lock contention
```

### 3. Performance Optimization

#### Query Optimization
```sql
-- Monitor query performance
-- Identify slow queries
-- Analyze execution plans
-- Add appropriate indexes
-- Rewrite inefficient queries
```

#### Index Optimization
```sql
-- Monitor index usage
-- Identify unused indexes
-- Create missing indexes
-- Rebuild fragmented indexes
-- Use partial indexes
```

### 4. Capacity Planning

#### Resource Monitoring
```sql
-- Monitor resource usage
-- CPU utilization
-- Memory usage
-- Disk I/O
-- Network bandwidth
-- Connection pool usage
```

#### Growth Planning
```sql
-- Monitor data growth
-- Plan for capacity upgrades
-- Schedule maintenance windows
-- Plan for hardware upgrades
```

## Common Issues and Solutions

### 1. High CPU Usage
```sql
-- Identify CPU-intensive queries
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    shared_blks_hit,
    shared_blks_read
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;

-- Solutions:
-- Optimize queries
-- Add indexes
-- Increase work_mem
-- Review configuration
```

### 2. Slow Queries
```sql
-- Identify slow queries
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'john@example.com';

-- Solutions:
-- Add indexes
-- Rewrite queries
-- Use appropriate join types
-- Increase work_mem
```

### 3. Replication Issues
```sql
-- Check replication status
SELECT 
    client_addr,
    usename,
    application_name,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn
FROM pg_stat_replication;

-- Solutions:
-- Check network connectivity
-- Increase WAL settings
-- Check disk space
-- Review configuration
```

### 4. Connection Issues
```sql
-- Monitor connections
SELECT 
    state,
    COUNT(*) AS connection_count
FROM pg_stat_activity
GROUP BY state;

-- Check connection limits
show max_connections;

-- Solutions:
-- Increase max_connections
-- Implement connection pooling
-- Optimize connection usage
-- Review application code
```

## Conclusion
Effective monitoring is crucial for maintaining PostgreSQL database performance and reliability in production environments. By implementing comprehensive monitoring strategies, using the right tools, and following best practices, you can ensure optimal database performance and quickly identify and resolve issues.

Remember to:
- Monitor key metrics regularly
- Set up appropriate alerts
- Use both built-in and external tools
- Monitor query performance
- Track replication status
- Monitor system resources
- Plan for capacity growth
- Test monitoring setup
- Document monitoring procedures
- Regularly review and adjust

With proper monitoring in place, you can maintain a healthy PostgreSQL database that meets your application's performance requirements and provides reliable service to your users.