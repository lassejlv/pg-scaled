#!/bin/bash
set -e

# Wait for primary to be ready
until pg_isready -h $POSTGRES_PRIMARY_HOST -p $POSTGRES_PRIMARY_PORT -U postgres; do
  echo "Waiting for primary PostgreSQL to be ready..."
  sleep 5
done

# Stop PostgreSQL if it's running
pg_ctl stop -D /var/lib/postgresql/data -m fast || true

# Remove existing data directory contents
rm -rf /var/lib/postgresql/data/*

# Create base backup from primary
echo "Creating base backup from primary..."
PGPASSWORD=${POSTGRES_REPLICATION_PASSWORD} pg_basebackup -h $POSTGRES_PRIMARY_HOST -p $POSTGRES_PRIMARY_PORT -U ${POSTGRES_REPLICATION_USER} -D /var/lib/postgresql/data -P -W -R

# Create standby.signal file to indicate this is a standby server
touch /var/lib/postgresql/data/standby.signal

# Update postgresql.auto.conf with replica settings
cat >> /var/lib/postgresql/data/postgresql.auto.conf <<EOF
primary_conninfo = 'host=$POSTGRES_PRIMARY_HOST port=$POSTGRES_PRIMARY_PORT user=${POSTGRES_REPLICATION_USER} password=${POSTGRES_REPLICATION_PASSWORD} application_name=$(hostname)'
primary_slot_name = 'replica_slot_$(hostname | sed 's/.*-//')'
restore_command = ''
archive_cleanup_command = ''
EOF

# Set proper permissions
chown -R postgres:postgres /var/lib/postgresql/data
chmod 700 /var/lib/postgresql/data

echo "Replica PostgreSQL setup completed successfully!"

# Start PostgreSQL in recovery mode
exec postgres -c config_file=/etc/postgresql/postgresql.conf
