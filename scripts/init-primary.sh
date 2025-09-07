#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
until pg_isready -h localhost -p 5432 -U postgres; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 2
done

# Create replication user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create replication user
    CREATE USER replicator REPLICATION LOGIN CONNECTION LIMIT 10 ENCRYPTED PASSWORD 'repl123';
    
    -- Create replication slots for replicas
    SELECT pg_create_physical_replication_slot('replica_slot_1');
    SELECT pg_create_physical_replication_slot('replica_slot_2');
    
    -- Grant necessary permissions
    GRANT CONNECT ON DATABASE scaleddb TO replicator;
    
    -- Create a sample table for testing
    CREATE TABLE IF NOT EXISTS test_data (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Insert some sample data
    INSERT INTO test_data (name) VALUES 
        ('Primary Server'),
        ('Sample Data 1'),
        ('Sample Data 2');
        
    -- Show replication status
    SELECT * FROM pg_stat_replication;
EOSQL

# Update pg_hba.conf to allow replication connections
echo "host replication replicator 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
echo "host all postgres 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf

# Reload configuration
pg_ctl reload -D /var/lib/postgresql/data

echo "Primary PostgreSQL setup completed successfully!"
