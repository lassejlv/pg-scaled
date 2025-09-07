#!/bin/bash

# PostgreSQL Cluster Management Script

set -e

COMPOSE_FILE="docker-compose.yml"

case "$1" in
    start)
        echo "Starting PostgreSQL cluster..."
        docker compose up -d
        echo "Waiting for services to be healthy..."
        sleep 30
        docker compose ps
        ;;
    stop)
        echo "Stopping PostgreSQL cluster..."
        docker compose down
        ;;
    restart)
        echo "Restarting PostgreSQL cluster..."
        docker compose down
        docker compose up -d
        ;;
    status)
        echo "PostgreSQL cluster status:"
        docker compose ps
        echo ""
        echo "Replication status:"
        docker exec postgres-primary psql -U postgres -d scaleddb -c "SELECT * FROM pg_stat_replication;" 2>/dev/null || echo "Primary not ready yet"
        ;;
    logs)
        service=${2:-postgres-primary}
        echo "Showing logs for $service..."
        docker compose logs -f $service
        ;;
    backup)
        timestamp=$(date +%Y%m%d_%H%M%S)
        backup_file="backup_${timestamp}.sql"
        echo "Creating backup: $backup_file"
        docker exec postgres-primary pg_dump -U postgres scaleddb > $backup_file
        echo "Backup completed: $backup_file"
        ;;
    connect)
        service=${2:-primary}
        case $service in
            primary|write)
                echo "Connecting to primary (write)..."
                docker exec -it postgres-primary psql -U postgres -d scaleddb
                ;;
            replica1)
                echo "Connecting to replica 1 (read-only)..."
                docker exec -it postgres-replica-1 psql -U postgres -d scaleddb
                ;;
            replica2)
                echo "Connecting to replica 2 (read-only)..."
                docker exec -it postgres-replica-2 psql -U postgres -d scaleddb
                ;;
            pooler)
                echo "Connecting via PgBouncer..."
                psql -h localhost -p 6432 -U postgres -d scaleddb
                ;;
            read)
                echo "Connecting to load balanced read endpoint..."
                psql -h localhost -p 5000 -U postgres -d scaleddb
                ;;
            *)
                echo "Unknown connection target: $service"
                echo "Available: primary, replica1, replica2, pooler, read"
                exit 1
                ;;
        esac
        ;;
    test)
        echo "Testing PostgreSQL cluster..."
        echo "1. Testing primary connection..."
        docker exec postgres-primary psql -U postgres -d scaleddb -c "SELECT 'Primary OK' as status, now() as timestamp;"
        
        echo "2. Testing replica connections..."
        docker exec postgres-replica-1 psql -U postgres -d scaleddb -c "SELECT 'Replica 1 OK' as status, now() as timestamp;" 2>/dev/null || echo "Replica 1 not ready"
        docker exec postgres-replica-2 psql -U postgres -d scaleddb -c "SELECT 'Replica 2 OK' as status, now() as timestamp;" 2>/dev/null || echo "Replica 2 not ready"
        
        echo "3. Testing replication..."
        docker exec postgres-primary psql -U postgres -d scaleddb -c "INSERT INTO test_data (name) VALUES ('Test $(date)');"
        sleep 2
        docker exec postgres-replica-1 psql -U postgres -d scaleddb -c "SELECT COUNT(*) as replica1_count FROM test_data;" 2>/dev/null || echo "Replica 1 not ready"
        ;;
    clean)
        echo "Cleaning up PostgreSQL cluster and volumes..."
        docker compose down -v
        docker volume prune -f
        ;;
    *)
        echo "PostgreSQL Cluster Management"
        echo "Usage: $0 {start|stop|restart|status|logs|backup|connect|test|clean}"
        echo ""
        echo "Commands:"
        echo "  start       - Start the PostgreSQL cluster"
        echo "  stop        - Stop the PostgreSQL cluster"
        echo "  restart     - Restart the PostgreSQL cluster"
        echo "  status      - Show cluster and replication status"
        echo "  logs [svc]  - Show logs (default: postgres-primary)"
        echo "  backup      - Create a database backup"
        echo "  connect [t] - Connect to database (primary|replica1|replica2|pooler|read)"
        echo "  test        - Test cluster functionality"
        echo "  clean       - Stop cluster and remove volumes"
        echo ""
        echo "Get connection strings with public IP:"
        echo "  ./get-connection-string.sh"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 connect replica1"
        echo "  $0 logs postgres-replica-1"
        exit 1
        ;;
esac
