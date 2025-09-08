# Scaled PostgreSQL Database with Docker Compose

A production-ready PostgreSQL setup with 1 primary and 2 replica instances, optimized for 4GB RAM and 3 vCPU.

## Architecture

- **postgres-primary**: Primary PostgreSQL instance (writes)
- **postgres-replica-1**: First read replica
- **postgres-replica-2**: Second read replica
- **pgbouncer**: Connection pooler
- **haproxy**: Load balancer for read operations

## Resource Allocation

- Primary: 1.5GB RAM, 1.0 CPU
- Each Replica: 1GB RAM, 0.8 CPU
- PgBouncer: 256MB RAM, 0.4 CPU
- HAProxy: 256MB RAM, 0.2 CPU

## Quick Start

```bash
# Start cluster with auto-generated credentials
./manage.sh start

# This will:
# - Generate secure random username/password
# - Start all PostgreSQL 17 services with environment variables
# - Create the database user with proper permissions
# - Display connection strings with your public IP
# - Save credentials to env.local

# View credentials anytime
./manage.sh credentials

# Manual start (loads from env.prod)
docker compose up -d
```

## Connection Endpoints

| Service             | Port | Purpose                                |
| ------------------- | ---- | -------------------------------------- |
| Primary DB          | 5432 | Direct primary connection (read/write) |
| Replica 1           | 5433 | Direct replica connection (read-only)  |
| Replica 2           | 5434 | Direct replica connection (read-only)  |
| PgBouncer           | 6432 | Pooled primary connection              |
| Read Load Balancer  | 5000 | Load balanced read queries             |
| Write Load Balancer | 5001 | Direct write to primary                |
| HAProxy Stats       | 8080 | HAProxy statistics dashboard           |

## Usage Examples

### Get Connection Strings with Public IP

```bash
# Get all connection strings
./get-connection-string.sh

# Get specific connection
./get-connection-string.sh primary
./get-connection-string.sh read
./get-connection-string.sh pooler

# Get as environment variables
./get-connection-string.sh env

# Get as JSON
./get-connection-string.sh json
```

### Connect to Primary (Write Operations)

```bash
psql -h localhost -p 5432 -U postgres -d scaleddb
```

### Connect to Load Balanced Reads

```bash
psql -h localhost -p 5000 -U postgres -d scaleddb
```

### Connect via PgBouncer

```bash
psql -h localhost -p 6432 -U postgres -d scaleddb
```

## Monitoring

### Check Replication Status

```sql
-- On primary
SELECT * FROM pg_stat_replication;

-- On replica
SELECT * FROM pg_stat_wal_receiver;
```

### HAProxy Stats

Visit http://localhost:8080/stats (admin/admin)

## Scaling Operations

### Add New Replica

1. Add new service to docker-compose.yml
2. Update HAProxy configuration
3. Restart services: `docker compose up -d`

### Manual Failover

```bash
# Promote replica to primary
docker exec postgres-replica-1 touch /tmp/promote_trigger
```

## Maintenance

### Backup

```bash
# Create backup from primary
docker exec postgres-primary pg_dump -U postgres scaleddb > backup.sql
```

### Stop Services

```bash
docker compose down
```

### Clean Restart

```bash
docker compose down -v
docker compose up -d
```

## Configuration Files

### Environment Files

- `env.prod`: Production configuration (ports, resources, passwords)
- `env.local`: Auto-generated user credentials (created by ./manage.sh start)
- `env.local.example`: Example credentials file

### Service Configurations

- `config/primary.conf`: Primary PostgreSQL configuration
- `config/replica.conf`: Replica PostgreSQL configuration
- `config/pgbouncer.ini`: PgBouncer connection pooler settings
- `config/haproxy.cfg`: HAProxy load balancer configuration

### Initialization Scripts

- `scripts/init-primary.sh`: Primary setup with environment variables
- `scripts/init-replica.sh`: Replica setup with environment variables

## Credentials & Environment Variables

### Auto-Generated User (Recommended)

When using `./manage.sh start`, secure credentials are automatically generated:

- Random username (e.g., `user_a3f7b982`)
- Random 16-character password
- Full database permissions
- Saved to `env.local` file
- Includes connection details (host, ports)

### Environment Configuration

All settings are controlled via `env.prod`:

- **Database**: `POSTGRES_DB=scaleddb`
- **Admin User**: `POSTGRES_ADMIN_USER=postgres`
- **Admin Password**: `POSTGRES_ADMIN_PASSWORD=postgres123`
- **Replication User**: `POSTGRES_REPLICATION_USER=replicator`
- **Replication Password**: `POSTGRES_REPLICATION_PASSWORD=repl123`
- **Ports**: `PRIMARY_PORT=5432`, `REPLICA1_PORT=5433`, etc.
- **Resource Limits**: Memory and CPU allocations

### Production Security

1. Change admin passwords in `env.prod`
2. Use `env.local` credentials for applications
3. Both files are in `.gitignore` for security

**⚠️ Update env.prod credentials before production deployment!**

## Troubleshooting

### Replica Not Syncing

```bash
# Check replication lag
docker exec postgres-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Restart replica
docker compose restart postgres-replica-1
```

### High Memory Usage

Adjust `shared_buffers` and `effective_cache_size` in config files.

### Connection Limits

Increase `max_connections` in PostgreSQL configs or adjust PgBouncer pool sizes.
