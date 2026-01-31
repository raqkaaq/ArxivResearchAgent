# PostgreSQL High Availability Setup Guide

## Overview
This comprehensive guide covers PostgreSQL high availability setup, including clustering, failover mechanisms, load balancing, monitoring, and best practices for creating resilient database systems.

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Clustering Solutions](#clustering-solutions)
3. [Failover Mechanisms](#failover-mechanisms)
4. [Load Balancing](#load-balancing)
5. [Monitoring and Alerting](#monitoring-and-alerting)
6. [Disaster Recovery](#disaster-recovery)
7. [Best Practices](#best-practices)

## Architecture Overview

### 1. High Availability Components

#### Basic HA Architecture
```
Client Applications
        |
    Load Balancer
   /     |      \
Primary  Standby1  Standby2
   |        |         |
  Data    Data      Data
```

#### Multi-site Architecture
```
Site A (Primary)
    |
Load Balancer
   /     \
Primary  Standby1
   |        |
  Data    Data

Site B (Secondary)
    |
Load Balancer
   /     \
Standby2  Standby3
   |        |
  Data    Data
```

### 2. High Availability Requirements

#### Key Requirements
- **Zero Downtime**: Continuous availability during maintenance and failures
- **Data Consistency**: No data loss during failover
- **Automatic Failover**: Quick recovery from failures
- **Load Balancing**: Even distribution of read operations
- **Monitoring**: Real-time health checks and alerts
- **Security**: Secure communication between components
- **Scalability**: Ability to handle growing workloads

#### Performance Considerations
- **Read Scalability**: Multiple read replicas
- **Write Scalability**: Limited by single primary
- **Network Latency**: Impact on synchronous replication
- **Resource Utilization**: CPU, memory, storage optimization
- **Backup Performance**: Minimal impact on production

## Clustering Solutions

### 1. Patroni

#### Patroni Architecture
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

#### Patroni Setup
```bash
# Install Patroni
pip install patroni[etcd]

# Create configuration
mkdir -p /etc/patroni
cp patroni.yml /etc/patroni/

# Create systemd service
cat <<EOF > /etc/systemd/system/patroni.service
[Unit]
Description=Patroni
After=network.target

[Service]
Type=simple
User=postgres
Group=postgres
ExecStart=/usr/local/bin/patroni /etc/patroni/patroni.yml
KillMode=process
TimeoutSec=30
Restart=no

[Install]
WantedBy=multi-user.target
EOF

# Start Patroni
sudo systemctl enable patroni
sudo systemctl start patroni
```

#### Patroni Commands
```bash
# Check cluster status
patronictl list

# Failover
patronictl failover --leader postgres1 --candidate postgres2 --scheduled

# Switchover
patronictl switchover --leader postgres1 --candidate postgres2

# Remove node
patronictl remove postgres3
```

### 2. repmgr

#### repmgr Architecture
```sql
-- Install repmgr extension
CREATE EXTENSION repmgr;

-- Register primary node
SELECT * FROM repmgr_primary.register_node(
    node_id := 1,
    conninfo := 'host=primary_ip port=5432 user=repmgr dbname=repmgr',
    node_name := 'primary1'
);

-- Register standby nodes
SELECT * FROM repmgr_standby.register_node(
    node_id := 2,
    conninfo := 'host=standby1_ip port=5432 user=repmgr dbname=repmgr',
    node_name := 'standby1',
    primary_conninfo := 'host=primary_ip port=5432 user=repmgr dbname=repmgr'
);
```

#### repmgr Configuration
```ini
# repmgr.conf
cluster=mycluster
node=1
timeout=60
reconnect_interval=2

conninfo=host=primary_ip port=5432 user=repmgr dbname=repmgr

log_level=INFO
log_facility=STDERR
log_file=/var/log/repmgr/repmgr.log

failover=automatic
promote_command='repmgr standby promote -f /etc/repmgr/repmgr.conf'
follow_command='repmgr standby follow -f /etc/repmgr/repmgr.conf'
```

#### repmgr Commands
```bash
# Initialize primary
repmgr primary register

# Register standby
repmgr standby register

# Monitor cluster
repmgr cluster show

# Failover
repmgr standby promote

# Follow new primary
repmgr standby follow
```

### 3. Pgpool-II

#### Pgpool-II Architecture
```ini
# pgpool.conf
backend_hostname0 = 'primary_ip'
backend_port0 = 5432
backend_weight0 = 1
backend_data_directory0 = '/var/lib/postgresql/15/main'
backend_flag0 = 'ALWAYS_PRIMARY'

backend_hostname1 = 'standby1_ip'
backend_port1 = 5432
backend_weight1 = 0.5
backend_data_directory1 = '/var/lib/postgresql/15/main'
backend_flag1 = 'ALWAYS_STANDBY'

# Load balancing settings
master_slave_mode = on
master_slave_sub_mode = 'stream'
load_balance_mode = on
replication_mode = off

# Health check settings
health_check_period = 10
health_check_timeout = 20
health_check_user = 'repmgr'
health_check_database = 'repmgr'
```

#### Pgpool-II Setup
```bash
# Install Pgpool-II
sudo apt-get install pgpool2

# Configure pgpool
cp /etc/pgpool2/pgpool.conf.sample-stream /etc/pgpool2/pgpool.conf
cp /etc/pgpool2/pcp.conf.sample /etc/pgpool2/pcp.conf

# Edit configuration files
# Add users to pcp.conf
# Configure backend settings in pgpool.conf

# Start Pgpool-II
sudo systemctl enable pgpool2
sudo systemctl start pgpool2
```

#### Pgpool-II Commands
```bash
# Check status
pcp_node_count -h localhost -p 9898 -U pcp_user

# Add node
pcp_attach_node -h localhost -p 9898 -U pcp_user -n 1

# Detach node
pcp_detach_node -h localhost -p 9898 -U pcp_user -n 1
```

## Failover Mechanisms

### 1. Automatic Failover

#### Patroni Failover
```bash
# Automatic failover with Patroni
# Patroni monitors cluster health and promotes standby automatically

# Check cluster status
patronictl list

# View failover history
patronictl history
```

#### repmgr Failover
```bash
# Automatic failover configuration
# Edit repmgr.conf
failover=automatic
promote_command='repmgr standby promote -f /etc/repmgr/repmgr.conf'
follow_command='repmgr standby follow -f /etc/repmgr/repmgr.conf'

# Monitor failover
repmgr cluster show
```

#### Custom Failover Script
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
    
    # Verify promotion
    if pg_isready -h $STANDBY_IP -p 5432; then
        echo "Standby promoted to primary successfully"
        
        # Update application configuration
        sed -i "s/$PRIMARY_IP/$STANDBY_IP/g" /etc/app/config.ini
        
        # Notify administrators
        echo "PostgreSQL failover completed" | mail -s "PostgreSQL Failover" admin@example.com
        
        exit 0
    else
        echo "Failover failed"
        exit 1
    fi
else
    echo "Primary is still up"
    exit 0
fi
```

### 2. Manual Failover

#### Manual Promotion
```sql
-- On standby server
-- Create trigger file
touch /tmp/postgresql.trigger.5432

-- Or use pg_ctl
pg_ctl promote -D /var/lib/postgresql/15/main

-- Check promotion status
SELECT pg_is_in_recovery(); -- Should return false after promotion
```

#### Switchover Process
```bash
# Planned switchover
# 1. Put primary in read-only mode
psql -h primary_ip -c "SELECT pg_read_only();"

# 2. Wait for replication to catch up
psql -h standby_ip -c "SELECT pg_is_in_recovery();"

# 3. Promote standby
ssh postgres@standby_ip "touch /tmp/postgresql.trigger.5432"

# 4. Update application configuration
# 5. Verify new primary
psql -h standby_ip -c "SELECT pg_is_in_recovery();"
```

## Load Balancing

### 1. Read Load Balancing

#### Pgpool-II Read Load Balancing
```ini
# pgpool.conf
load_balance_mode = on
# Enable read query load balancing

backend_weight0 = 1  # Primary
backend_weight1 = 2  # Standby (more weight for reads)

# Read-only function detection
enable_readonly_function = on

# White and black list
allow_readonly_function = 'SELECT|SHOW|SET|BEGIN|COMMIT|ROLLBACK'
```

#### PgBouncer Connection Pooling
```ini
# pgbouncer.ini
[databases]
mydb = host=pgpool_ip port=6432 dbname=mydb

[pgbouncer]
listen_addr = *
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt

# Pool settings
default_pool_size = 20
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 5

# Server settings
server_reset_query = DISCARD ALL
server_check_query = SELECT 1
server_check_delay = 10
```

#### Application-Level Load Balancing
```python
# Python connection pool example
import psycopg2
from psycopg2 import pool

class DatabasePool:
    def __init__(self):
        self.primary_pool = psycopg2.pool.SimpleConnectionPool(
            1, 20,
            user='postgres',
            password='password',
            host='primary_ip',
            port='5432',
            database='mydb'
        )
        
        self.standby_pool = psycopg2.pool.SimpleConnectionPool(
            1, 20,
            user='postgres',
            password='password',
            host='standby_ip',
            port='5432',
            database='mydb'
        )
    
    def get_connection(self, read_only=False):
        if read_only:
            return self.standby_pool.getconn()
        else:
            return self.primary_pool.getconn()
    
    def return_connection(self, conn, read_only=False):
        if read_only:
            self.standby_pool.putconn(conn)
        else:
            self.primary_pool.putconn(conn)
```

### 2. Write Load Distribution

#### Multi-primary Setup
```sql
-- Multi-primary setup with BDR (Bi-Directional Replication)
-- Install BDR extension
CREATE EXTENSION bdr;

-- Create BDR group
SELECT bdr.create_node_group(
    node_group_name := 'my_cluster',
    node_name := 'primary1',
    node_connstr := 'host=primary_ip port=5432 dbname=mydb user=replicator'
);

-- Join other nodes to group
SELECT bdr.join_node_group(
    node_group_name := 'my_cluster',
    join_type := 'dcs',
    node_name := 'primary2',
    node_connstr := 'host=primary2_ip port=5432 dbname=mydb user=replicator'
);
```

#### Sharding
```sql
-- Create hash-based sharding
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(255),
    shard_key INTEGER GENERATED ALWAYS AS (id % 4) STORED
) PARTITION BY LIST (shard_key);

-- Create shard partitions
CREATE TABLE users_shard_0 PARTITION OF users 
FOR VALUES IN (0);

CREATE TABLE users_shard_1 PARTITION OF users 
FOR VALUES IN (1);

CREATE TABLE users_shard_2 PARTITION OF users 
FOR VALUES IN (2);

CREATE TABLE users_shard_3 PARTITION OF users 
FOR VALUES IN (3);
```

## Monitoring and Alerting

### 1. Cluster Monitoring

#### System Monitoring
```sql
-- Monitor system resources
SELECT 
    pg_postmaster_start_time() AS postgres_start_time,
    pg_conf_load_time() AS config_load_time,
    date_trunc('second', current_timestamp - pg_postmaster_start_time()) AS uptime,
    (SELECT setting::integer FROM pg_settings WHERE name = 'max_connections') AS max_connections,
    (SELECT COUNT(*) FROM pg_stat_activity) AS current_connections,
    (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active') AS active_connections;
```

#### Replication Monitoring
```sql
-- Monitor replication status
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

#### Performance Monitoring
```sql
-- Monitor query performance
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
ORDER BY total_time DESC
LIMIT 10;
```

### 2. Alert Configuration

#### Alert Thresholds
```sql
-- Replication lag alert
SELECT 
    client_addr,
    usename,
    application_name,
    EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS lag_seconds
FROM pg_stat_replication
WHERE lag_seconds > 60; -- Alert if lag exceeds 60 seconds

-- Connection pool alert
SELECT 
    datname,
    numbackends,
    max_connections,
    (numbackends::float / max_connections) * 100 AS connection_usage
FROM pg_stat_database
WHERE (numbackends::float / max_connections) * 100 > 80; -- Alert if usage exceeds 80%
```

#### Monitoring Tools
```bash
# Install monitoring tools
# Prometheus
# Grafana
# Nagios
# Zabbix

# Configure PostgreSQL exporter
# docker run -d -p 9187:9187 -v /var/lib/postgresql:/var/lib/postgresql wrouesnel/postgres_exporter
```

## Disaster Recovery

### 1. Backup Strategies

#### Physical Backups
```sql
-- Create physical backup
pg_basebackup -h primary_ip -U replicator -D /backup/base -vP -W

-- Continuous archiving
archive_command = 'cp %p /backup/archive/%f'
archive_timeout = 300
```

#### Logical Backups
```sql
-- Create logical backup
pg_dump -h primary_ip -U postgres -F c -b -v -f /backup/mydb.dump mydb

-- Restore logical backup
pg_restore -h standby_ip -U postgres -d mydb -v /backup/mydb.dump
```

### 2. Point-in-Time Recovery

#### PITR Configuration
```sql
-- Configure for PITR
restore_command = 'cp /backup/archive/%f %p'
recovery_target_time = '2024-01-15 10:30:00'
recovery_target_inclusive = true
```

#### Recovery Process
```bash
# Stop PostgreSQL
sudo systemctl stop postgresql

# Restore from backup
sudo -u postgres pg_basebackup -h primary_ip -U replicator -D /var/lib/postgresql/15/main -vP -W

# Configure recovery
sudo -u postgres cp recovery.conf /var/lib/postgresql/15/main/

# Start PostgreSQL
sudo systemctl start postgresql
```

### 3. Disaster Recovery Plan

#### DR Procedures
```bash
# DR script example
#!/bin/bash
# dr_recovery.sh
PRIMARY_IP=$1
STANDBY_IP=$2
BACKUP_DIR=$3

# Check if primary is down
if ! pg_isready -h $PRIMARY_IP -p 5432; then
    echo "Primary is down, starting disaster recovery..."
    
    # Restore from backup
    sudo -u postgres pg_basebackup -h $STANDBY_IP -U replicator -D /var/lib/postgresql/15/main -vP -W
    
    # Configure as primary
    sudo rm -f /var/lib/postgresql/15/main/recovery.conf
    sudo touch /var/lib/postgresql/15/main/postgresql.trigger.5432
    
    # Start PostgreSQL
sudo systemctl start postgresql
    
    echo "Disaster recovery completed"
else
    echo "Primary is up, no recovery needed"
fi
```

## Best Practices

### 1. Architecture Design

#### Multi-site Deployment
```
Site A (Primary)
    |
Load Balancer
   /     \
Primary  Standby1
   |        |
  Data    Data

Site B (Secondary)
    |
Load Balancer
   /     \
Standby2  Standby3
   |        |
  Data    Data
```

#### Network Configuration
```sql
-- Configure network for HA
# Separate network for replication
# Redundant network connections
# Proper firewall rules
# VPN for site-to-site connectivity
```

### 2. Security

#### Secure Communication
```sql
-- SSL configuration
hostssl replication replicator 192.168.1.0/24 md5
hostssl replication replicator 10.0.0.0/8 md5

-- SSL settings
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'
ssl_ca_file = '/etc/ssl/certs/ca.crt'
```

#### Access Control
```sql
-- Principle of least privilege
CREATE USER read_replica WITH LOGIN;
GRANT CONNECT ON DATABASE mydb TO read_replica;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO read_replica;

-- Dedicated replication user
CREATE USER replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'strong_password';
```

### 3. Performance Optimization

#### Resource Allocation
```sql
-- Memory configuration
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 16MB
maintenance_work_mem = 1GB

-- Connection settings
max_connections = 100
shared_preload_libraries = 'pg_stat_statements'
```

#### Query Optimization
```sql
-- Optimize for HA environment
-- Use prepared statements
-- Implement connection pooling
-- Optimize for partition pruning
-- Use appropriate indexes
```

### 4. Monitoring and Testing

#### Regular Testing
```bash
-- Test failover procedures monthly
# Test backup and restore procedures
# Test monitoring and alerting
# Test performance under load
```

#### Documentation
```bash
# Document all procedures
# Recovery procedures
# Failover procedures
# Configuration settings
# Contact information
```

## Common Issues and Solutions

### 1. Network Partition
```sql
-- Detect network partition
SELECT 
    client_addr,
    state,
    sync_state,
    EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS lag_seconds
FROM pg_stat_replication;

-- Solutions:
-- Implement quorum-based decisions
-- Use fencing mechanisms
-- Configure proper timeouts
-- Monitor network connectivity
```

### 2. Split Brain
```sql
-- Prevent split brain
-- Use quorum-based decisions
-- Implement fencing
-- Configure proper timeouts
-- Monitor cluster health
```

### 3. Performance Degradation
```sql
-- Monitor performance
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
-- Scale resources
-- Review configuration
```

## Conclusion
PostgreSQL high availability setup requires careful planning, proper configuration, and ongoing maintenance. By implementing the right clustering solution, configuring proper failover mechanisms, and following best practices, you can create a resilient database system that ensures continuous availability and data protection.

Remember to:
- Choose the right HA solution for your needs
- Test failover procedures regularly
- Monitor cluster health continuously
- Keep documentation updated
- Plan for disaster recovery
- Regularly backup your data
- Monitor performance metrics
- Implement proper security measures
- Scale resources appropriately
- Test under realistic workloads
- Keep software updated

With proper implementation of PostgreSQL high availability, you can ensure your database systems remain available and reliable even during failures and maintenance periods.