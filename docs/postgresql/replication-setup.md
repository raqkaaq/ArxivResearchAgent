# PostgreSQL Replication Setup Guide

## Overview
This comprehensive guide covers PostgreSQL replication setup, including physical replication, logical replication, configuration, monitoring, and best practices for creating highly available database systems.

## Table of Contents
1. [Physical Replication](#physical-replication)
2. [Logical Replication](#logical-replication)
3. [Configuration](#configuration)
4. [Monitoring and Maintenance](#monitoring-and-maintenance)
5. [Failover and High Availability](#failover-and-high-availability)
6. [Best Practices](#best-practices)

## Physical Replication

### 1. Streaming Replication

#### Basic Setup
```sql
-- Primary server configuration
-- Edit postgresql.conf
wal_level = replica
max_wal_senders = 3
synchronous_commit = off
archive_mode = on
archive_command = 'cp %p /path/to/archive/%f'

-- Edit pg_hba.conf
host replication replicator 192.168.1.0/24 md5

-- Create replication user
CREATE USER replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'replication_password';

-- Restart PostgreSQL
sudo systemctl restart postgresql
```

#### Standby Server Setup
```sql
-- Stop PostgreSQL on standby
sudo systemctl stop postgresql

-- Remove existing data directory
sudo rm -rf /var/lib/postgresql/15/main

-- Perform base backup
sudo -u postgres pg_basebackup -h primary_ip -U replicator -D /var/lib/postgresql/15/main -vP -W

-- Create recovery.conf
standby_mode = 'on'
primary_conninfo = 'host=primary_ip port=5432 user=replicator application_name=standby1'
trigger_file = '/tmp/postgresql.trigger.5432'

-- Start PostgreSQL on standby
sudo systemctl start postgresql
```

#### Synchronous Replication
```sql
-- Primary server configuration
-- Edit postgresql.conf
wal_level = replica
max_wal_senders = 5
synchronous_commit = on
synchronous_standby_names = 'standby1, standby2'

-- Standby server configuration
-- Create recovery.conf
standby_mode = 'on'
primary_conninfo = 'host=primary_ip port=5432 user=replicator application_name=standby1'
trigger_file = '/tmp/postgresql.trigger.5432'

-- Restart both servers
```

### 2. Replication Slots

#### Creating Replication Slots
```sql
-- Create physical replication slot
SELECT * FROM pg_create_physical_replication_slot('standby1_slot');

-- Create logical replication slot
SELECT * FROM pg_create_logical_replication_slot('standby1_logical', 'pgoutput');

-- View replication slots
SELECT * FROM pg_replication_slots;
```

#### Standby Configuration with Slots
```sql
-- Standby recovery.conf
standby_mode = 'on'
primary_conninfo = 'host=primary_ip port=5432 user=replicator application_name=standby1'
trigger_file = '/tmp/postgresql.trigger.5432'
primary_slot_name = 'standby1_slot'
```

## Logical Replication

### 1. Basic Logical Replication

#### Publication Setup
```sql
-- Primary server
-- Create publication
CREATE PUBLICATION my_publication FOR TABLE users, orders;

-- Or publish all tables
CREATE PUBLICATION my_publication FOR ALL TABLES;

-- Publish specific operations
CREATE PUBLICATION my_publication FOR TABLE users, orders
WITH (publish = 'insert, update, delete');
```

#### Subscription Setup
```sql
-- Standby/Subscriber server
-- Create subscription
CREATE SUBSCRIPTION my_subscription 
CONNECTION 'host=primary_ip port=5432 user=replicator password=replication_password dbname=mydb'
PUBLICATION my_publication;

-- View subscriptions
SELECT * FROM pg_stat_subscription;
SELECT * FROM pg_subscription;
```

#### Selective Replication
```sql
-- Publish specific columns
CREATE PUBLICATION my_publication FOR TABLE users(
    id, name, email
);

-- Publish using WHERE clause
CREATE PUBLICATION my_publication FOR TABLE orders
WHERE amount > 1000;
```

### 2. Advanced Logical Replication

#### Multiple Publications
```sql
-- Create multiple publications
CREATE PUBLICATION users_publication FOR TABLE users;
CREATE PUBLICATION orders_publication FOR TABLE orders;

-- Subscribe to specific publications
CREATE SUBSCRIPTION users_subscription 
CONNECTION 'host=primary_ip port=5432 user=replicator password=replication_password dbname=mydb'
PUBLICATION users_publication;

CREATE SUBSCRIPTION orders_subscription 
CONNECTION 'host=primary_ip port=5432 user=replicator password=replication_password dbname=mydb'
PUBLICATION orders_publication;
```

#### Column-level Replication
```sql
-- Publish specific columns
CREATE PUBLICATION column_level_pub FOR TABLE users(
    id, name, email, created_at
);

-- Subscribe to column-level publication
CREATE SUBSCRIPTION column_level_sub 
CONNECTION 'host=primary_ip port=5432 user=replicator password=replication_password dbname=mydb'
PUBLICATION column_level_pub;
```

#### Row-level Filtering
```sql
-- Publish with WHERE clause
CREATE PUBLICATION filtered_pub FOR TABLE orders
WHERE status = 'completed';

-- Subscribe to filtered publication
CREATE SUBSCRIPTION filtered_sub 
CONNECTION 'host=primary_ip port=5432 user=replicator password=replication_password dbname=mydb'
PUBLICATION filtered_pub;
```

## Configuration

### 1. Primary Server Configuration

#### postgresql.conf Settings
```sql
# Primary server settings
wal_level = replica
max_wal_senders = 5  # Number of standby servers
max_replication_slots = 5  # Number of replication slots
synchronous_commit = off  # Change to on for synchronous replication
archive_mode = on
archive_command = 'cp %p /path/to/archive/%f'

# Performance settings
shared_buffers = 4GB
work_mem = 16MB
maintenance_work_mem = 1GB
effective_cache_size = 12GB

# Connection settings
max_connections = 100
shared_preload_libraries = 'pg_stat_statements'
```

#### pg_hba.conf Settings
```sql
# Replication connections
host replication replicator 192.168.1.0/24 md5
host replication replicator 10.0.0.0/8 md5

# Application connections
host all all 192.168.1.0/24 md5
host all all 10.0.0.0/8 md5
```

### 2. Standby Server Configuration

#### Standby Settings
```sql
# Standby server settings
wal_level = replica
max_wal_senders = 3
hot_standby = on
max_standby_streaming_delay = 30s
wal_receiver_status_interval = 10s
hot_standby_feedback = on

# Connection settings
max_connections = 100
shared_preload_libraries = 'pg_stat_statements'
```

#### Recovery Configuration
```sql
# recovery.conf (PostgreSQL < 12)
standby_mode = 'on'
primary_conninfo = 'host=primary_ip port=5432 user=replicator application_name=standby1'
trigger_file = '/tmp/postgresql.trigger.5432'
primary_slot_name = 'standby1_slot'

# Create standby.signal (PostgreSQL ≥ 12)
# Create standby.signal file in data directory
# Create postgresql.auto.conf
standby_mode = 'on'
primary_conninfo = 'host=primary_ip port=5432 user=replicator application_name=standby1'
trigger_file = '/tmp/postgresql.trigger.5432'
primary_slot_name = 'standby1_slot'
```

## Monitoring and Maintenance

### 1. Replication Monitoring

#### Primary Server Monitoring
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
    sync_state
FROM pg_stat_replication;

-- Check replication slots
SELECT * FROM pg_replication_slots;

-- Check replication lag
SELECT 
    client_addr,
    usename,
    application_name,
    EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS replication_lag_seconds
FROM pg_stat_replication;
```

#### Standby Server Monitoring
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
    latest_end_time
FROM pg_stat_wal_receiver;

-- Check replication slots on standby
SELECT * FROM pg_replication_slots;
```

### 2. Performance Monitoring

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

-- Monitor WAL generation
SELECT 
    pg_current_wal_lsn() AS current_wal_lsn,
    pg_walfile_name(pg_current_wal_lsn()) AS current_wal_file,
    pg_wal_lsn_diff(pg_current_wal_lsn(), 
                   pg_walfile_name_offset(pg_current_wal_lsn())::pg_lsn) AS current_wal_offset;
```

#### System Monitoring
```sql
-- Monitor system resources
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
```

### 3. Maintenance Tasks

#### Regular Maintenance
```sql
-- Update statistics
ANALYZE;

-- Vacuum maintenance
VACUUM ANALYZE;

-- Reindex if needed
REINDEX DATABASE mydb;
```

#### Replication Slot Maintenance
```sql
-- Clean up unused replication slots
SELECT pg_drop_replication_slot('standby1_slot');

-- Monitor slot usage
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
FROM pg_replication_slots;
```

## Failover and High Availability

### 1. Manual Failover

#### Trigger Standby Promotion
```sql
-- On standby server
-- Create trigger file
touch /tmp/postgresql.trigger.5432

-- Or use pg_ctl
pg_ctl promote -D /var/lib/postgresql/15/main

-- Check promotion status
SELECT pg_is_in_recovery(); -- Should return false after promotion
```

#### Failover Script
```bash
#!/bin/bash
# failover.sh
PRIMARY_IP=$1
STANDBY_IP=$2

# Check primary status
if ! pg_isready -h $PRIMARY_IP -p 5432; then
    echo "Primary is down, promoting standby..."
    
    # Promote standby
    ssh postgres@$STANDBY_IP "touch /tmp/postgresql.trigger.5432"
    
    # Wait for promotion
    sleep 30
    
    # Check if standby is now primary
    if pg_isready -h $STANDBY_IP -p 5432; then
        echo "Failover completed successfully"
    else
        echo "Failover failed"
        exit 1
    fi
else
    echo "Primary is still up"
    exit 0
fi
```

### 2. Automatic Failover

#### Using Patroni
```yaml
# patroni.yml
scope: mycluster
data_dir: /var/lib/postgresql/15/main

bootstrap:
  dcs:
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        max_wal_senders: 5
        hot_standby: on
  initdb: []
  pg_hba:
    - host replication replicator 0.0.0.0/0 md5
    - host all all 0.0.0.0/0 md5

restapi:
  listen: 0.0.0.0:8008
  connect_address: 127.0.0.1:8008

timeout: 30

auth:
  username: patroni
  password: patroni

watchdog:
  mode: automatic
  device: /dev/watchdog
  safety_margin: 5

cluster: mycluster
```

#### Using repmgr
```sql
-- Install repmgr
CREATE EXTENSION repmgr;

-- Register primary node
SELECT * FROM repmgr_primary.register_node(
    node_id := 1,
    conninfo := 'host=primary_ip port=5432 user=repmgr dbname=repmgr',
    node_name := 'primary1'
);

-- Register standby node
SELECT * FROM repmgr_standby.register_node(
    node_id := 2,
    conninfo := 'host=standby_ip port=5432 user=repmgr dbname=repmgr',
    node_name := 'standby1',
    primary_conninfo := 'host=primary_ip port=5432 user=repmgr dbname=repmgr'
);
```

### 3. Load Balancing

#### Pgpool-II Configuration
```ini
# pgpool.conf
backend_hostname0 = 'primary_ip'
backend_port0 = 5432
backend_weight0 = 1
backend_data_directory0 = '/var/lib/postgresql/15/main'
backend_flag0 = 'ALWAYS_PRIMARY'

backend_hostname1 = 'standby_ip'
backend_port1 = 5432
backend_weight1 = 0.5
backend_data_directory1 = '/var/lib/postgresql/15/main'
backend_flag1 = 'ALWAYS_STANDBY'

# Load balancing settings
master_slave_mode = on
master_slave_sub_mode = 'stream'
load_balance_mode = on
```

## Best Practices

### 1. Security

#### Secure Replication
```sql
-- Use SSL for replication
hostssl replication replicator 192.168.1.0/24 md5
hostssl replication replicator 10.0.0.0/8 md5

-- Configure SSL
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'
ssl_ca_file = '/etc/ssl/certs/ca.crt'
```

#### User Management
```sql
-- Create dedicated replication user
CREATE USER replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'strong_password';

-- Grant minimal privileges
GRANT REPLICATION ON DATABASE mydb TO replicator;
```

### 2. Performance

#### WAL Configuration
```sql
-- Optimize WAL for replication
wal_level = replica
max_wal_senders = 5
wal_keep_segments = 32
wal_sender_timeout = 60s

-- Archive settings
archive_mode = on
archive_command = 'cp %p /path/to/archive/%f'
archive_timeout = 300
```

#### Connection Management
```sql
-- Set appropriate connection limits
max_connections = 100
max_prepared_transactions = 10

-- Configure connection pool
shared_preload_libraries = 'pg_stat_statements'
```

### 3. Monitoring

#### Alert Configuration
```sql
-- Set up monitoring alerts
-- Replication lag exceeds threshold
-- Primary server down
-- Standby server down
-- Replication slot full
-- High WAL generation
```

#### Performance Metrics
```sql
-- Monitor key metrics
-- Replication delay
-- WAL generation rate
-- Connection status
-- System resources
-- Query performance
```

### 4. Backup and Recovery

#### Backup Strategy
```sql
-- Regular base backups
pg_basebackup -h primary_ip -U replicator -D /backup/base -vP -W

-- Continuous archiving
archive_command = 'cp %p /backup/archive/%f'

-- Point-in-time recovery
recovery_target_time = '2024-01-15 10:30:00'
```

#### Disaster Recovery
```sql
-- Test recovery procedures regularly
-- Document recovery steps
-- Keep backup copies offsite
-- Test failover procedures
```

## Common Issues and Solutions

### 1. Replication Lag
```sql
-- Identify lag causes
SELECT 
    client_addr,
    usename,
    application_name,
    EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS lag_seconds
FROM pg_stat_replication;

-- Solutions:
-- Increase network bandwidth
-- Optimize primary server performance
-- Check standby server resources
-- Increase wal_keep_segments
```

### 2. Connection Issues
```sql
-- Check connection settings
SELECT * FROM pg_stat_activity 
WHERE application_name LIKE '%replicator%';

-- Check firewall settings
# sudo ufw status
# sudo iptables -L

-- Check pg_hba.conf settings
```

### 3. Data Inconsistency
```sql
-- Check data consistency
SELECT 
    COUNT(*) AS primary_count
FROM primary_database.users;

SELECT 
    COUNT(*) AS standby_count
FROM standby_database.users;

-- Compare checksums
SELECT md5(string_agg(id::text, '')) FROM users;
```

## Conclusion
PostgreSQL replication is a powerful feature for creating highly available database systems. By understanding the different replication methods, proper configuration, and following best practices, you can build robust and reliable database infrastructure.

Remember to:
- Choose the right replication method for your needs
- Configure security properly
- Monitor replication health regularly
- Test failover procedures
- Keep documentation updated
- Regularly backup your data
- Monitor performance metrics
- Plan for disaster recovery
- Keep software updated
- Test recovery procedures regularly

With proper implementation of PostgreSQL replication, you can ensure high availability, data protection, and scalability for your database systems.