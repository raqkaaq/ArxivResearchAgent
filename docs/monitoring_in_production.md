# Monitoring in Production Guide

## Overview
Monitoring is essential for maintaining the health, performance, and reliability of LangGraph applications in production. This guide covers comprehensive monitoring strategies, tools, and best practices.

## Table of Contents
1. [Monitoring Fundamentals](#monitoring-fundamentals)
2. [Application Metrics](#application-metrics)
3. [Infrastructure Monitoring](#infrastructure-monitoring)
4. [Distributed Tracing](#distributed-tracing)
5. [Log Management](#log-management)
6. [Alerting and Incident Response](#alerting-and-incident-response)
7. [Performance Monitoring](#performance-monitoring)
8. [Security Monitoring](#security-monitoring)
9. [Cost Monitoring](#cost-monitoring)
10. [Best Practices](#best-practices)

## Monitoring Fundamentals

### What to Monitor

#### Key Metrics Categories
```javascript
// Application Metrics
const appMetrics = {
  responseTime: {
    p50: 120,    // Median response time
    p95: 500,    // 95th percentile
    p99: 1200    // 99th percentile
  },
  errorRate: {
    total: 0.02, // 2% error rate
    types: {
      erc20: 0.01,
      validation: 0.005,
      database: 0.005
    }
  },
  throughput: {
    requestsPerSecond: 100,
    concurrentRequests: 50
  }
};

// Infrastructure Metrics
const infraMetrics = {
  cpu: {
    usage: 65,    // CPU usage percentage
    load: 2.1     // System load average
  },
  memory: {
    usage: 8192,  // Memory usage in MB
    available: 16384
  },
  disk: {
    usage: 60,    // Disk usage percentage
    io: 1000      // IOPS
  }
};
```

#### Business Metrics
```javascript
// Business metrics
const businessMetrics = {
  userEngagement: {
    activeUsers: 1250,
    sessions: 5000,
    conversionRate: 0.15
  },
  revenue: {
    total: 12500,
    averageOrderValue: 100
  }
};
```

### Monitoring Stack

#### Open Source Stack
```yaml
# Monitoring stack components
monitoring:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards

  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"
      - "14268:14268"

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.16.3
    ports:
      - "9200:9200"

  logstash:
    image: docker.elastic.co/logstash/logstash:7.16.3
    ports:
      - "5044:5044"

  kibana:
    image: docker.elastic.co/kibana/kibana:7.16.3
    ports:
      - "5601:5601"
```

#### Commercial Solutions
```javascript
// Commercial monitoring solutions
const monitoringSolutions = {
  datadog: {
    features: [
      'Application Performance Monitoring',
      'Infrastructure Monitoring',
      'Log Management',
      'Security Monitoring',
      'RUM (Real User Monitoring)'
    ],
    pricing: {
      infrastructure: '$15/node/month',
      apm: '$31/host/month',
      logs: '$0.1/GB'
    }
  },
  newrelic: {
    features: [
      'Application Monitoring',
      'Infrastructure Monitoring',
      'Network Monitoring',
      'Synthetic Monitoring'
    ],
    pricing: {
      full_stack: '$0.25/host/hour'
    }
  },
  datadog: {
    features: [
      'Application Performance Monitoring',
      'Infrastructure Monitoring',
      'Log Management',
      'Security Monitoring',
      'RUM (Real User Monitoring)'
    ],
    pricing: {
      infrastructure: '$15/node/month',
      apm: '$31/host/month',
      logs: '$0.1/GB'
    }
  }
};
```

## Application Metrics

### Custom Metrics

#### LangGraph-Specific Metrics
```javascript
// LangGraph metrics collection
const langGraphMetrics = {
  graphExecution: {
    totalExecutions: 0,
    successfulExecutions: 0,
    failedExecutions: 0,
    averageExecutionTime: 0,
    maxExecutionTime: 0,
    minExecutionTime: 0
  },
  nodeExecution: {
    totalNodesExecuted: 0,
    successfulNodes: 0,
    failedNodes: 0,
    averageNodeTime: 0,
    maxNodeTime: 0,
    minNodeTime: 0
  },
  messagePassing: {
    totalMessages: 0,
    successfulMessages: 0,
    failedMessages: 0,
    averageMessageTime: 0,
    maxMessageTime: 0,
    minMessageTime: 0
  }
};
```

#### Prometheus Metrics
```javascript
// Prometheus metrics collection
const prometheusMetrics = {
  httpRequestsTotal: {
    help: 'Total number of HTTP requests',
    type: 'counter',
    labels: ['method', 'endpoint', 'status']
  },
  httpRequestDurationSeconds: {
    help: 'HTTP request duration in seconds',
    type: 'histogram',
    buckets: [0.1, 0.5, 1, 2, 5, 10]
  },
  httpRequestsInFlight: {
    help: 'Current number of requests in flight',
    type: 'gauge'
  },
  memoryUsageBytes: {
    help: 'Memory usage in bytes',
    type: 'gauge'
  },
  cpuUsagePercentage: {
    help: 'CPU usage percentage',
    type: 'gauge'
  }
};
```

#### Application Performance Metrics
```javascript
// Performance metrics
const performanceMetrics = {
  responseTime: {
    p50: 120,    // Median response time
    p95: 500,    // 95th percentile
    p99: 1200    // 99th percentile
  },
  throughput: {
    requestsPerSecond: 100,
    concurrentRequests: 50
  },
  errorRate: {
    total: 0.02, // 2% error rate
    types: {
      erc20: 0.01,
      validation: 0.005,
      database: 0.005
    }
  }
};
```

### Metrics Collection

#### Node.js Metrics Collection
```javascript
// Node.js metrics collection
const promClient = require('prom-client');

// Create metrics registry
const register = new promClient.Registry();

// Create metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  buckets: [0.1, 0.5, 1, 2, 5, 10]
});

const httpRequestTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'endpoint', 'status']
});

const httpRequestInFlight = new promClient.Gauge({
  name: 'http_requests_in_flight',
  help: 'Current number of requests in flight'
});

// Register metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestTotal);
register.registerMetric(httpRequestInFlight);

// Middleware for metrics collection
const metricsMiddleware = (req, res, next) => {
  const startTime = Date.now();
  httpRequestInFlight.inc();
  
  const end = res.end;
  res.end = (...args) ={
    const duration = (Date.now() - startTime) / 1000;
    httpRequestDuration.observe(duration);
    httpRequestTotal.inc({ method: req.method, endpoint: req.path, status: res.statusCode });
    httpRequestInFlight.dec();
    end.apply(res, args);
  };
  
  next();
};
```

#### Python Metrics Collection
```python
# Python metrics collection
from prometheus_client import Histogram, Counter, Gauge, start_http_server
import time
import random

# Create metrics
http_request_duration = Histogram(
    'http_request_duration_seconds',
    'Duration of HTTP requests in seconds',
    ['method', 'endpoint', 'status'],
    buckets=[0.1, 0.5, 1, 2, 5, 10]
)

http_requests_total = Counter(
    'http_requests_total',
    'Total number of HTTP requests',
    ['method', 'endpoint', 'status']
)

http_requests_in_flight = Gauge(
    'http_requests_in_flight',
    'Current number of requests in flight'
)

# Start metrics server
start_http_server(8000)

# Middleware for metrics collection
def metrics_middleware(get_response):
    def middleware(request):
        start_time = time.time()
        http_requests_in_flight.inc()
        
        try:
            response = get_response(request)
            duration = time.time() - start_time
            http_request_duration.labels(
                method=request.method,
                endpoint=request.path,
                status=response.status_code
            ).observe(duration)
            http_requests_total.labels(
                method=request.method,
                endpoint=request.path,
                status=response.status_code
            ).inc()
            return response
        finally:
            http_requests_in_flight.dec()
    
    return middleware
```

## Infrastructure Monitoring

### System Metrics

#### CPU Monitoring
```javascript
// CPU monitoring
const cpuMetrics = {
  usage: {
    user: 65,      // User CPU usage
    system: 25,    // System CPU usage
    idle: 10       // Idle CPU
  },
  load: {
    oneMinute: 2.1,
    fiveMinute: 1.8,
    fifteenMinute: 1.5
  },
  cores: 8,
  frequency: {
    current: 2.4,  // GHz
    max: 3.5
  }
};
```

#### Memory Monitoring
```javascript
// Memory monitoring
const memoryMetrics = {
  usage: {
    total: 16384,  // Total memory in MB
    used: 8192,    // Used memory in MB
    free: 8192,    // Free memory in MB
    available: 12288
  },
  swap: {
    total: 2048,
    used: 512,
    free: 1536
  },
  buffers: 256,
  cache: 1024
};
```

#### Disk Monitoring
```javascript
// Disk monitoring
const diskMetrics = {
  usage: {
    total: 1000000,  // Total disk space in MB
    used: 600000,    // Used disk space in MB
    free: 400000,    // Free disk space in MB
    usagePercentage: 60
  },
  io: {
    readBytesPerSecond: 100000,
    writeBytesPerSecond: 50000,
    iops: 1000
  },
  partitions: [
    {
      device: '/dev/sda1',
      mountPoint: '/',
      usage: 70
    }
  ]
};
```

### Network Monitoring

#### Network Metrics
```javascript
// Network monitoring
const networkMetrics = {
  interfaces: {
    eth0: {
      bytesPerSecond: {
        received: 100000,
        sent: 50000
      },
      packetsPerSecond: {
        received: 1000,
        sent: 500
      },
      errors: {
        received: 0,
        sent: 0
      },
      drops: {
        received: 10,
        sent: 5
      }
    }
  },
  connections: {
    established: 150,
    listening: 10,
    timeWait: 20,
    closeWait: 5
  }
};
```

#### Bandwidth Monitoring
```javascript
// Bandwidth monitoring
const bandwidthMetrics = {
  total: {
    received: 1000000000,  // Total bytes received
    sent: 500000000        // Total bytes sent
  },
  rate: {
    received: 100000,      // Bytes per second
    sent: 50000
  },
  peak: {
    received: 200000,
    sent: 100000
  }
};
```

## Distributed Tracing

### Tracing Fundamentals

#### Trace Context
```javascript
// Trace context
const traceContext = {
  traceId: '1234567890abcdef1234567890abcdef',
  spanId: 'abcdef1234567890',
  parentId: '1234567890abcdef',
  sampled: true,
  flags: 1
};
```

#### Span Information
```javascript
// Span information
const spanInfo = {
  operationName: 'http_request',
  startTime: 1672444800000,
  duration: 120,
  tags: {
    'http.method': 'GET',
    'http.url': '/api/users',
    'http.status_code': 200,
    'peer.address': '192.168.1.100:3000'
  },
  logs: [
    {
      timestamp: 1672444800100,
      fields: {
        'event': 'request_received'
      }
    }
  ]
};
```

### Jaeger Integration

#### Node.js Tracing
```javascript
// Node.js Jaeger tracing
const { initTracer } = require('jaeger-client');

const config = {
  serviceName: 'langgraph-app',
  sampler: {
    type: 'const',
    param: 1
  },
  reporter: {
    logSpans: true
  }
};

const options = {
  logger: {
    info: function logInfo(msg) {
      console.log('INFO ', msg);
    },
    error: function logError(msg) {
      console.log('ERROR', msg);
    }
  }
};

const tracer = initTracer(config, options);

// Middleware for tracing
const tracingMiddleware = (req, res, next) ={
  const span = tracer.startSpan('http_request');
  span.setTag('http.method', req.method);
  span.setTag('http.url', req.url);
  
  const startTime = Date.now();
  
  const end = res.end;
  res.end = (...args) = {
    const duration = Date.now() - startTime;
    span.setTag('http.status_code', res.statusCode);
    span.finish();
    end.apply(res, args);
  };
  
  next();
};
```

#### Python Tracing
```python
# Python Jaeger tracing
from jaeger_client import Config
import logging

def init_tracer():
    logging.getLogger('').handlers = []
    logging.basicConfig(format='%(message)s', level=logging.DEBUG)
    
    config = Config(
        config={  # usually read from some yaml config
            'sampler': {
                'type': 'const',
                'param': 1,
            },
            'logging': True,
        },
        service_name='langgraph-app'
    )
    
    return config.initialize_tracer()

def tracing_middleware(get_response):
    def middleware(request):
        tracer = init_tracer()
        with tracer.start_span('http_request') as span:
            span.set_tag('http.method', request.method)
            span.set_tag('http.url', request.path)
            
            start_time = time.time()
            
            try:
                response = get_response(request)
                duration = time.time() - start_time
                span.set_tag('http.status_code', response.status_code)
                span.finish()
                return response
            except Exception as e:
                span.set_tag('error', True)
                span.log_kv({
                    'event': 'error',
                    'message': str(e)
                })
                span.finish()
                raise
    
    return middleware
```

## Log Management

### Log Structure

#### Structured Logging
```javascript
// Structured logging
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'app.log' }),
    new winston.transports.Console()
  ]
});

// Log with context
logger.info('Request processed', {
  requestId: req.id,
  userId: req.user.id,
  duration: duration,
  endpoint: req.path,
  method: req.method,
  status: res.statusCode
});
```

#### Log Levels
```javascript
// Log levels
const logLevels = {
  error: {
    level: 0,
    description: 'Error events that might still allow the application to continue running.'
  },
  warn: {
    level: 1,
    description: 'Potentially harmful situations.'
  },
  info: {
    level: 2,
    description: 'Interesting events.'
  },
  http: {
    level: 3,
    description: 'HTTP requests'
  },
  verbose: {
    level: 4,
    description: 'Verbose information'
  },
  debug: {
    level: 5,
    description: 'Debug-level messages'
  },
  silly: {
    level: 6,
    description: 'Super detailed debugging information'
  }
};
```

### Log Aggregation

#### ELK Stack
```yaml
# docker-compose.yml
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.16.3
    ports:
      - "9200:9200"
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:7.16.3
    ports:
      - "5044:5044"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf

  kibana:
    image: docker.elastic.co/kibana/kibana:7.16.3
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

volumes:
  elasticsearch_data:
```

#### Logstash Configuration
```ruby
# logstash.conf
input {
  beats {
    port => 5044
  }
}

filter {
  json {
    source => "message"
  }
  
  date {
    match => [ "timestamp", "ISO8601" ]
  }
  
  mutate {
    remove_field => ["@version", "@timestamp"]
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    index => "langgraph-logs-%{+YYYY.MM.dd}"
  }
  
  stdout {
    codec => rubydebug
  }
}
```

## Alerting and Incident Response

### Alerting Rules

#### Prometheus Alerting
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

#### Alert Rules
```yaml
# alert_rules.yml
groups:
- name: langgraph-alerts
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      description: "Error rate is above 5% for the last 2 minutes"

  - alert: HighResponseTime
    expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High response time detected"
      description: "95th percentile response time is above 1 second"

  - alert: HighMemoryUsage
    expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage detected"
      description: "Memory usage is above 80% for the last 5 minutes"

  - alert: HighCPUUsage
    expr: 100 - (node_cpu_seconds_total{mode="idle"} / ignoring(cpu) group_left rate(node_cpu_seconds_total[5m])) * 100 > 90
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage detected"
      description: "CPU usage is above 90% for the last 5 minutes"
```

### Incident Response

#### Incident Management
```javascript
// Incident management
const incidentResponse = {
  onCall: {
    engineer: {
      name: "John Doe",
      phone: "+1234567890",
      email: "john@example.com"
    },
    backup: {
      name: "Jane Smith",
      phone: "+0987654321",
      email: "jane@example.com"
    }
  },
  escalation: [
    {
      level: 1,
      contacts: ["john@example.com", "jane@example.com"]
    },
    {
      level: 2,
      contacts: ["manager@example.com"]
    }
  ],
  communication: {
    slack: {
      channel: "#incidents",
      webhook: "https://hooks.slack.com/services/..."
    },
    email: {
      from: "alerts@example.com",
      to: ["team@example.com"]
    }
  }
};
```

#### Incident Playbooks
```yaml
# Incident playbooks
incident_playbooks:
  high_error_rate:
    steps:
      - check_error_logs
      - identify_error_type
      - restart_service_if_needed
      - escalate_if_persistent
    
  high_memory_usage:
    steps:
      - check_memory_usage
      - identify_memory_leaks
      - restart_service_if_needed
      - escalate_if_persistent
    
  database_connection_issues:
    steps:
      - check_database_connection
      - verify_database_status
      - restart_database_if_needed
      - escalate_if_persistent
```

## Performance Monitoring

### Application Performance

#### Performance Metrics
```javascript
// Application performance metrics
const appPerformanceMetrics = {
  responseTime: {
    p50: 120,    // Median response time
    p95: 500,    // 95th percentile
    p99: 1200    // 99th percentile
  },
  throughput: {
    requestsPerSecond: 100,
    concurrentRequests: 50
  },
  errorRate: {
    total: 0.02, // 2% error rate
    types: {
      validation: 0.005,
      database: 0.01,
      network: 0.005
    }
  },
  availability: {
    uptime: 0.99, // 99% uptime
    downtime: 0.01
  }
};
```

#### Performance Testing
```javascript
// Performance testing
const performanceTesting = {
  loadTesting: {
    concurrentUsers: 1000,
    rampUpTime: 60,  // seconds
    testDuration: 300  // seconds
  },
  stressTesting: {
    maxUsers: 2000,
    testDuration: 600
  },
  enduranceTesting: {
    users: 500,
    testDuration: 3600  // 1 hour
  }
};
```

### Database Performance

#### Database Metrics
```javascript
// Database metrics
const databaseMetrics = {
  connectionPool: {
    activeConnections: 50,
    maxConnections: 100,
    idleConnections: 30
  },
  queryPerformance: {
    averageQueryTime: 100,  // ms
    slowQueries: 5,        // queries > 1s
    queryCacheHitRate: 0.8
  },
  transactionMetrics: {
    totalTransactions: 1000,
    successfulTransactions: 950,
    failedTransactions: 50,
    averageTransactionTime: 200
  }
};
```

#### Database Monitoring
```yaml
# Database monitoring configuration
database_monitoring:
  prometheus:
    scrape_interval: 30s
    metrics_path: /metrics
  
  queries:
    - name: database_connections
      query: "SELECT count(*) FROM pg_stat_activity WHERE state = 'active'"
      labels: ['database', 'user']
    
    - name: query_performance
      query: "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10"
      labels: ['query']
    
    - name: transaction_metrics
      query: "SELECT sum(xact_commit) as commits, sum(xact_rollback) as rollbacks FROM pg_stat_database"
      labels: ['database']
```

## Security Monitoring

### Security Metrics

#### Security Events
```javascript
// Security events
const securityEvents = {
  authentication: {
    successfulLogins: 1000,
    failedLogins: 50,
    loginRate: 20
  },
  authorization: {
    accessDenied: 10,
    permissionChanges: 5
  },
  intrusionAttempts: {
    blockedAttempts: 100,
    suspiciousActivity: 20
  }
};
```

#### Vulnerability Scanning
```javascript
// Vulnerability scanning
const vulnerabilityScanning = {
  scanResults: {
    critical: 2,
    high: 5,
    medium: 10,
    low: 20
  },
  scanFrequency: {
    daily: true,
    weekly: true,
    monthly: true
  },
  scanTools: [
    'trivy',
    'clair',
    'anchore'
  ]
};
```

### Security Monitoring Tools

#### SIEM Integration
```yaml
# SIEM integration
security_monitoring:
  siem:
    type: splunk
    url: https://splunk.example.com
    token: ${SPLUNK_TOKEN}
  
  log_sources:
    - type: application
      source: /var/log/app.log
      format: json
    - type: security
      source: /var/log/security.log
      format: syslog
    - type: network
      source: /var/log/network.log
      format: json
```

#### WAF Monitoring
```javascript
// WAF monitoring
const wafMonitoring = {
  rules: {
    enabled: 100,
    active: 95,
    bypassed: 5
  },
  attacksBlocked: {
    sqlInjection: 50,
    xss: 30,
    csrf: 20,
    other: 10
  },
  trafficAnalysis: {
    allowed: 95000,
    blocked: 500,
    rateLimit: 100
  }
};
```

## Cost Monitoring

### Resource Cost

#### Cloud Cost Monitoring
```javascript
// Cloud cost monitoring
const cloudCostMonitoring = {
  aws: {
    ec2: {
      instances: 10,
      costPerHour: 5,
      totalCost: 3600  // monthly
    },
    rds: {
      instances: 2,
      costPerHour: 3,
      totalCost: 2160
    },
    s3: {
      storage: 1000,  // GB
      costPerMonth: 25
    }
  },
  gcp: {
    compute: {
      instances: 8,
      costPerHour: 4,
      totalCost: 2880
    },
    cloud_sql: {
      instances: 2,
      costPerHour: 2.5,
      totalCost: 1800
    },
    cloud_storage: {
      storage: 1000,
      costPerMonth: 20
    }
  }
};
```

#### Cost Optimization
```javascript
// Cost optimization
const costOptimization = {
  rightsizing: {
    underutilizedInstances: 3,
    potentialSavings: 1200
  },
  reservedInstances: {
    purchased: 5,
    savings: 2000
  },
  spotInstances: {
    used: 2,
    savings: 500
  }
};
```

### Usage Monitoring

#### API Usage
```javascript
// API usage monitoring
const apiUsageMonitoring = {
  endpoints: {
    '/api/users': {
      requests: 10000,
      cost: 50
    },
    '/api/orders': {
      requests: 5000,
      cost: 25
    },
    '/api/products': {
      requests: 8000,
      cost: 40
    }
  },
  costPerRequest: 0.01,
  totalCost: 115
};
```

#### Storage Usage
```javascript
// Storage usage monitoring
const storageUsageMonitoring = {
  database: {
    size: 100,  // GB
    cost: 100
  },
  logs: {
    size: 50,   // GB
    cost: 25
  },
  backups: {
    size: 200,  // GB
    cost: 50
  },
  total: {
    size: 350,
    cost: 175
  }
};
```

## Best Practices

### Monitoring Strategy

#### Monitoring Pyramid
```javascript
// Monitoring pyramid
const monitoringPyramid = {
  logs: {
    foundation: true,
    volume: 'high',
    importance: 'critical'
  },
  metrics: {
    foundation: true,
    volume: 'medium',
    importance: 'high'
  },
  traces: {
    foundation: false,
    volume: 'low',
    importance: 'medium'
  },
  alerts: {
    foundation: true,
    volume: 'low',
    importance: 'critical'
  }
};
```

#### Golden Signals
```javascript
// Golden signals monitoring
const goldenSignals = {
  latency: {
    p50: 120,    // Median response time
    p95: 500,    // 95th percentile
    p99: 1200    // 99th percentile
  },
  traffic: {
    requestsPerSecond: 100,
    concurrentRequests: 50
  },
  errors: {
    rate: 0.02,  // 2% error rate
    types: {
      validation: 0.005,
      database: 0.01,
      network: 0.005
    }
  },
  saturation: {
    cpu: 65,     // CPU usage percentage
    memory: 70,  // Memory usage percentage
    disk: 60     // Disk usage percentage
  }
};
```

### Implementation

#### Monitoring as Code
```yaml
# Monitoring as code
monitoring_as_code:
  prometheus:
    config: prometheus.yml
    rules: alert_rules.yml
    dashboards: grafana_dashboards/
  
  grafana:
    dashboards:
      - name: langgraph-overview
        file: dashboards/langgraph-overview.json
      - name: langgraph-performance
        file: dashboards/langgraph-performance.json
      - name: langgraph-errors
        file: dashboards/langgraph-errors.json
  
  alerting:
    rules:
      - name: high-error-rate
        file: alerts/high-error-rate.yml
      - name: high-response-time
        file: alerts/high-response-time.yml
```

#### Testing Monitoring
```javascript
// Testing monitoring
const monitoringTesting = {
  alertTesting: {
    frequency: 'weekly',
    methods: ['email', 'slack', 'pagerduty'],
    successCriteria: 'alerts received and acknowledged'
  },
  dashboardTesting: {
    frequency: 'monthly',
    tests: ['data accuracy', 'visual correctness', 'accessibility']
  },
  metricTesting: {
    frequency: 'daily',
    tests: ['data completeness', 'accuracy', 'consistency']
  }
};
```

## Conclusion

Effective monitoring is crucial for maintaining the health, performance, and reliability of LangGraph applications in production. By implementing comprehensive monitoring strategies that cover application metrics, infrastructure monitoring, distributed tracing, log management, alerting, and security monitoring, you can ensure your applications run smoothly and issues are detected and resolved quickly.

Key takeaways:
- Implement comprehensive monitoring across all layers
- Use multiple monitoring tools and approaches
- Set up proper alerting and incident response
- Monitor security and cost alongside performance
- Follow best practices and continuously improve
- Test monitoring systems regularly
- Document monitoring procedures and playbooks

For more information, explore the official documentation for Prometheus, Grafana, Jaeger, and other monitoring tools, and stay updated with the latest monitoring best practices and technologies.

---

*This guide provides comprehensive monitoring strategies for LangGraph applications in production, covering all aspects from basic metrics collection to advanced distributed tracing and security monitoring.*