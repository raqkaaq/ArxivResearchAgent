# PostgreSQL Backup and Recovery Procedures Guide

## Overview
This comprehensive guide covers PostgreSQL backup and recovery procedures, including physical backups, logical backups, continuous archiving, point-in-time recovery, and best practices for ensuring data protection and business continuity.

## Table of Contents
1. [Backup Strategies](#backup-strategies)
2. [Physical Backups](#physical-backups)
3. [Logical Backups](#logical-backups)
4. [Continuous Archiving](#continuous-archiving)
5. [Point-in-Time Recovery](#point-in-time-recovery)
6. [Recovery Procedures](#recovery-procedures)
7. [Automation and Monitoring](#automation-and-monitoring)
8. [Best Practices](#best-practices)

## Backup Strategies

### 1. Backup Types

#### Full Backups
- **Complete database backup**
- **Large storage requirements**
- **Fast recovery time**
- **Regular schedule (daily/weekly)**

#### Incremental Backups
- **Only changed data**
- **Smaller storage requirements**
- **Longer recovery time**
- **Frequent schedule (hourly/daily)**

#### Differential Backups
- **Changes since last full backup**
- **Moderate storage requirements**
- **Faster recovery than incremental**
- **Combined with full backups**

### 2. Backup Schedule

#### Daily Backup Schedule
```sql
-- Full backup: Weekly (Sunday)
-- Differential backup: Daily (Monday-Saturday)
-- Transaction log backup: Hourly

-- Example cron jobs
0 2 * * 0 /backup/full_backup.sh  # Sunday 2:00 AM
0 3 * * 1-6 /backup/diff_backup.sh  # Monday-Saturday 3:00 AM
0 * * * * /backup/log_backup.sh  # Hourly
```

#### Retention Policy
```sql
-- Full backups: Keep 4 weeks
-- Differential backups: Keep 7 days
-- Transaction log backups: Keep 24 hours
-- Archive logs: Keep 30 days
```

## Physical Backups

### 1. Base Backups

#### Basic Base Backup
```sql
-- Create base backup
pg_basebackup -h primary_ip -U replicator -D /backup/base -vP -W

-- With compression
pg_basebackup -h primary_ip -U replicator -D /backup/base -zP -vP -W

-- With parallel processing
pg_basebackup -h primary_ip -U replicator -D /backup/base -j 4 -vP -W
```

#### Base Backup with Tablespaces
```sql
-- Create base backup with tablespaces
pg_basebackup -h primary_ip -U replicator -D /backup/base -T "*" -vP -W

-- Map tablespaces
pg_basebackup -h primary_ip -U replicator -D /backup/base -T "old_tablespace:new_tablespace" -vP -W
```

#### Base Backup Verification
```sql
-- Verify backup integrity
pg_verifybackup /backup/base

-- Check backup contents
ls -la /backup/base/
find /backup/base/ -type f -name "*.backup" -o -name "*.sql" | head -10
```

### 2. File System Backups

#### File System Backup
```bash
# Stop PostgreSQL
sudo systemctl stop postgresql

# Create file system backup
tar -czf /backup/full_backup_$(date +%Y%m%d_%H%M%S).tar.gz /var/lib/postgresql/15/main

# Or use rsync
rsync -av --progress /var/lib/postgresql/15/main/ /backup/rsync/

# Start PostgreSQL
sudo systemctl start postgresql
```

#### LVM Snapshot Backup
```bash
# Create LVM snapshot
sudo lvcreate -L 10G -s -n postgres_snapshot /dev/vg0/postgresql

# Mount snapshot
sudo mkdir -p /mnt/snapshot
sudo mount /dev/vg0/postgres_snapshot /mnt/snapshot

# Create backup from snapshot
rsync -av --progress /mnt/snapshot/ /backup/lvm/

# Unmount and remove snapshot
sudo umount /mnt/snapshot
sudo lvremove -f /dev/vg0/postgres_snapshot
```

## Logical Backups

### 1. pg_dump

#### Full Database Backup
```sql
-- Full database backup
pg_dump -h primary_ip -U postgres -F c -b -v -f /backup/mydb.dump mydb

-- With compression
pg_dump -h primary_ip -U postgres -F c -b -v -Z 9 -f /backup/mydb.dump mydb

-- Custom format with compression
pg_dump -h primary_ip -U postgres -F d -b -v -f /backup/mydb_custom mydb
```

#### Selective Backup
```sql
-- Backup specific tables
pg_dump -h primary_ip -U postgres -F c -b -v -t users -t orders -f /backup/mydb_tables.dump mydb

-- Backup specific schemas
pg_dump -h primary_ip -U postgres -F c -b -v -n public -n sales -f /backup/mydb_schemas.dump mydb

-- Backup with WHERE clause
pg_dump -h primary_ip -U postgres -F c -b -v -t "users WHERE created_at > '2024-01-01'" -f /backup/mydb_filtered.dump mydb
```

#### Parallel Backup
```sql
-- Parallel dump with multiple jobs
pg_dump -h primary_ip -U postgres -F d -j 4 -b -v -f /backup/mydb_parallel mydb
```

### 2. pg_dumpall

#### Complete Cluster Backup
```sql
-- Backup entire cluster
pg_dumpall -h primary_ip -U postgres -f /backup/cluster_backup.sql

-- Backup with globals only
pg_dumpall -h primary_ip -U postgres -g -f /backup/cluster_globals.sql

-- Backup with specific options
pg_dumpall -h primary_ip -U postgres -f /backup/cluster_backup.sql --roles --tablespaces --databases
```

#### Selective Cluster Backup
```sql
-- Backup specific databases
pg_dumpall -h primary_ip -U postgres -f /backup/cluster_backup.sql --databases mydb1,mydb2

-- Backup with specific options
pg_dumpall -h primary_ip -U postgres -f /backup/cluster_backup.sql --roles --tablespaces --encoding=UTF8
```

## Continuous Archiving

### 1. WAL Archiving

#### Archive Configuration
```sql
-- postgresql.conf settings
wal_level = replica
archive_mode = on
archive_command = 'cp %p /backup/archive/%f'
archive_timeout = 300

-- Create archive directory
mkdir -p /backup/archive
chown postgres:postgres /backup/archive
```

#### Archive Script
```bash
#!/bin/bash
# archive_command.sh

SOURCE_FILE=$1
DEST_FILE=$2

# Copy WAL file to archive
cp $SOURCE_FILE /backup/archive/$DEST_FILE

# Verify copy
if [ $? -eq 0 ]; then
    echo "Archived: $DEST_FILE"
    exit 0
else
    echo "Archive failed: $DEST_FILE"
    exit 1
fi
```

#### Archive Monitoring
```sql
-- Check archive status
SELECT 
    pg_current_wal_lsn() AS current_wal_lsn,
    pg_walfile_name(pg_current_wal_lsn()) AS current_wal_file,
    pg_wal_lsn_diff(pg_current_wal_lsn(), 
                   pg_walfile_name_offset(pg_current_wal_lsn())::pg_lsn) AS current_wal_offset;

-- Check archive status
SELECT * FROM pg_stat_archiver;
```

### 2. Continuous Backup

#### Streaming Backup
```sql
-- Create continuous backup script
#!/bin/bash

BACKUP_DIR=/backup/continuous
KEEP_DAYS=7

# Create backup directory
mkdir -p $BACKUP_DIR

# Create base backup
pg_basebackup -h primary_ip -U replicator -D $BACKUP_DIR/base -zP -vP -W

# Create recovery.conf for continuous recovery
cat > $BACKUP_DIR/recovery.conf <<EOF
standby_mode = 'on'
primary_conninfo = 'host=primary_ip port=5432 user=replicator application_name=continuous_backup'
restore_command = 'cp /backup/archive/%f %p'
archive_cleanup_command = '/pg_archivecleanup /backup/archive %r'
trigger_file = '/tmp/postgresql.trigger.5432'
EOF

# Create recovery.signal for PostgreSQL >= 12
touch $BACKUP_DIR/recovery.signal
```

## Point-in-Time Recovery

### 1. PITR Configuration

#### Recovery Configuration
```sql
-- recovery.conf (PostgreSQL < 12)
restore_command = 'cp /backup/archive/%f %p'
recovery_target_time = '2024-01-15 10:30:00'
recovery_target_inclusive = true
trigger_file = '/tmp/postgresql.trigger.5432'

-- postgresql.conf (PostgreSQL >= 12)
# Create recovery.signal file
# Create postgresql.auto.conf
restore_command = 'cp /backup/archive/%f %p'
recovery_target_time = '2024-01-15 10:30:00'
recovery_target_inclusive = true
trigger_file = '/tmp/postgresql.trigger.5432'
```

#### Recovery Targets
```sql
-- Time-based recovery
recovery_target_time = '2024-01-15 10:30:00'

-- Transaction ID recovery
recovery_target_xid = 1234567

-- Consistency-based recovery
recovery_target = 'immediate'

-- Inclusive recovery
recovery_target_inclusive = true  -- Include the target point
recovery_target_inclusive = false  -- Stop before the target point
```

### 2. PITR Procedures

#### Full Recovery
```bash
# Stop PostgreSQL
sudo systemctl stop postgresql

# Remove existing data directory
sudo rm -rf /var/lib/postgresql/15/main

# Restore from base backup
sudo -u postgres pg_basebackup -h primary_ip -U replicator -D /var/lib/postgresql/15/main -vP -W

# Configure recovery
sudo -u postgres cp recovery.conf /var/lib/postgresql/15/main/

# Start PostgreSQL
sudo systemctl start postgresql
```

#### Point-in-Time Recovery
```bash
# Stop PostgreSQL
sudo systemctl stop postgresql

# Remove existing data directory
sudo rm -rf /var/lib/postgresql/15/main

# Restore from base backup
sudo -u postgres pg_basebackup -h primary_ip -U replicator -D /var/lib/postgresql/15/main -vP -W

# Configure PITR
sudo -u postgres cp pitr_recovery.conf /var/lib/postgresql/15/main/recovery.conf

# Start PostgreSQL
sudo systemctl start postgresql

# Monitor recovery
psql -c "SELECT pg_is_in_recovery();"
```

## Recovery Procedures

### 1. Database Recovery

#### Simple Recovery
```bash
#!/bin/bash
# simple_recovery.sh
BACKUP_DIR=$1

# Stop PostgreSQL
sudo systemctl stop postgresql

# Remove existing data directory
sudo rm -rf /var/lib/postgresql/15/main

# Restore from backup
sudo -u postgres pg_basebackup -h primary_ip -U replicator -D /var/lib/postgresql/15/main -vP -W

# Start PostgreSQL
sudo systemctl start postgresql

# Verify recovery
psql -c "SELECT version();"
psql -c "SELECT COUNT(*) FROM users;"
```

#### Point-in-Time Recovery
```bash
#!/bin/bash
# pitr_recovery.sh
BACKUP_DIR=$1
TARGET_TIME=$2

# Stop PostgreSQL
sudo systemctl stop postgresql

# Remove existing data directory
sudo rm -rf /var/lib/postgresql/15/main

# Restore from base backup
sudo -u postgres pg_basebackup -h primary_ip -U replicator -D /var/lib/postgresql/15/main -vP -W

# Configure PITR
sudo -u postgres cp pitr_recovery.conf /var/lib/postgresql/15/main/recovery.conf

# Update recovery target time
sudo sed -i "s/RECOVERY_TARGET_TIME/$TARGET_TIME/" /var/lib/postgresql/15/main/recovery.conf

# Start PostgreSQL
sudo systemctl start postgresql

# Monitor recovery
while psql -c "SELECT pg_is_in_recovery();" | grep -q "t"; do
    echo "Recovery in progress..."
    sleep 10
done

echo "Recovery completed"
```

### 2. Disaster Recovery

#### Complete Disaster Recovery
```bash
#!/bin/bash
# disaster_recovery.sh
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

#### Partial Recovery
```bash
#!/bin/bash
# partial_recovery.sh
DATABASE=$1
TABLES=$2

# Restore specific tables
pg_restore -h primary_ip -U postgres -d $DATABASE -t $TABLES /backup/mydb.dump

# Verify recovery
psql -d $DATABASE -c "SELECT COUNT(*) FROM $TABLES;"
```

## Automation and Monitoring

### 1. Backup Automation

#### Automated Backup Script
```bash
#!/bin/bash
# automated_backup.sh
BACKUP_TYPE=$1
BACKUP_DIR=/backup
DATE=$(date +%Y%m%d_%H%M%S)

case $BACKUP_TYPE in
    "full")
        echo "Starting full backup..."
        pg_basebackup -h primary_ip -U replicator -D $BACKUP_DIR/full_$DATE -zP -vP -W
        ;;
    "differential")
        echo "Starting differential backup..."
        pg_dump -h primary_ip -U postgres -F c -b -v -f $BACKUP_DIR/diff_$DATE.dump mydb
        ;;
    "log")
        echo "Starting transaction log backup..."
        # Implement log backup logic
        ;;
    *)
        echo "Unknown backup type: $BACKUP_TYPE"
        exit 1
        ;;
esac

# Remove old backups
find $BACKUP_DIR -name "*.dump" -mtime +7 -delete
find $BACKUP_DIR -name "*.backup" -mtime +30 -delete
```

#### Backup Monitoring
```sql
-- Monitor backup status
SELECT 
    pg_current_wal_lsn() AS current_wal_lsn,
    pg_walfile_name(pg_current_wal_lsn()) AS current_wal_file,
    pg_wal_lsn_diff(pg_current_wal_lsn(), 
                   pg_walfile_name_offset(pg_current_wal_lsn())::pg_lsn) AS current_wal_offset;

-- Check archive status
SELECT * FROM pg_stat_archiver;
```

### 2. Recovery Monitoring

#### Recovery Status Monitoring
```sql
-- Monitor recovery progress
SELECT 
    pg_is_in_recovery() AS in_recovery,
    pg_last_xact_replay_timestamp() AS last_replay_time,
    pg_last_wal_receive_lsn() AS last_receive_lsn,
    pg_last_wal_replay_lsn() AS last_replay_lsn,
    EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS replay_lag_seconds;

-- Check recovery target
SELECT 
    recovery_target,
    recovery_target_inclusive,
    recovery_target_time,
    recovery_target_xid,
    recovery_target_name
FROM pg_control_recovery();
```

#### Alert Configuration
```sql
-- Set up monitoring alerts
-- Backup failure
-- Recovery failure
-- Replication lag
-- Disk space usage
-- Archive corruption
```

## Best Practices

### 1. Backup Strategy

#### 3-2-1 Backup Rule
```
3 copies of data
2 different storage media
1 copy offsite
```

#### Backup Frequency
```sql
-- Critical databases: Daily full backup, hourly log backup
-- Important databases: Weekly full backup, daily differential backup
-- Development databases: Weekly full backup
```

### 2. Security

#### Secure Backups
```bash
# Encrypt backups
pg_dump -h primary_ip -U postgres -F c -b -v -f /backup/mydb.dump mydb --compress=9 --no-password

# Use encryption tools
gpg -c /backup/mydb.dump

# Secure backup location
chmod 600 /backup/*
chown postgres:postgres /backup
```

#### Access Control
```sql
-- Restrict backup access
REVOKE ALL ON DATABASE mydb FROM public;
GRANT CONNECT ON DATABASE mydb TO backup_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup_user;
```

### 3. Testing

#### Regular Testing
```bash
# Test backup recovery monthly
# Test disaster recovery quarterly
# Test point-in-time recovery annually
# Test backup integrity weekly
```

#### Documentation
```bash
# Document all procedures
# Recovery steps
# Contact information
# Configuration settings
# Testing results
```

### 4. Performance Optimization

#### Backup Performance
```sql
-- Optimize backup performance
pg_dump -h primary_ip -U postgres -F d -j 4 -b -v -f /backup/mydb_parallel mydb

-- Monitor backup performance
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements
WHERE query LIKE '%pg_dump%'
ORDER BY total_time DESC;
```

#### Recovery Performance
```sql
-- Optimize recovery performance
-- Use parallel recovery
-- Configure appropriate memory
-- Monitor I/O performance
-- Use SSD storage
```

## Common Issues and Solutions

### 1. Backup Failure
```sql
-- Check backup logs
tail -f /var/log/postgresql/postgresql-15-main.log

-- Verify disk space
df -h /backup

-- Check permissions
ls -la /backup
```

### 2. Recovery Failure
```sql
-- Check recovery logs
tail -f /var/log/postgresql/postgresql-15-main.log

-- Verify backup integrity
pg_verifybackup /backup/base

-- Check configuration
cat /var/lib/postgresql/15/main/recovery.conf
```

### 3. Data Corruption
```sql
-- Check data integrity
SELECT COUNT(*) FROM users;
SELECT md5(string_agg(id::text, '')) FROM users;

-- Verify checksums
pg_verifychecksums /var/lib/postgresql/15/main
```

## Conclusion
PostgreSQL backup and recovery procedures are essential for protecting your data and ensuring business continuity. By implementing comprehensive backup strategies, following best practices, and regularly testing recovery procedures, you can ensure your PostgreSQL databases are protected against data loss and system failures.

Remember to:
- Implement the 3-2-1 backup rule
- Test backups regularly
- Document all procedures
- Monitor backup and recovery processes
- Keep backup software updated
- Train staff on recovery procedures
- Review and update procedures regularly
- Test disaster recovery plans
- Monitor storage usage
- Ensure proper security

With proper backup and recovery procedures in place, you can ensure your PostgreSQL databases remain protected and recoverable in case of any data loss or system failure.