#!/bin/bash

# PostgreSQL Cluster Management Script

set -e

COMPOSE_FILE="docker-compose.yml"

generate_credentials() {
    # Generate random username and password
    DB_USER="user_$(openssl rand -hex 4)"
    DB_PASSWORD="$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)"
    
    # Get host info
    DB_HOST=$(get_public_ip)
    
    # Save credentials to env.local file
    cat > env.local <<EOF
# Generated User Credentials (created by ./manage.sh start)
# This file is auto-generated and should not be committed to version control

# Application Database User (auto-generated)
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_NAME=scaleddb

# Connection Details (auto-detected)
DB_HOST=$DB_HOST
DB_PRIMARY_PORT=5432
DB_READ_PORT=5000
DB_POOLER_PORT=6432
EOF
    
    echo "Generated credentials saved to env.local"
    echo "Username: $DB_USER"
    echo "Password: $DB_PASSWORD"
}

create_user_in_db() {
    echo "Creating database user: $DB_USER"
    
    # Create user in primary database
    docker exec postgres-primary psql -U postgres -d scaleddb -c "
        DROP USER IF EXISTS $DB_USER;
        CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
        GRANT CONNECT ON DATABASE scaleddb TO $DB_USER;
        GRANT USAGE ON SCHEMA public TO $DB_USER;
        GRANT CREATE ON SCHEMA public TO $DB_USER;
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $DB_USER;
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $DB_USER;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
    " 2>/dev/null || echo "Warning: Could not create user yet, database may still be initializing"
}

get_public_ip() {
    # Try multiple services to get public IP
    local public_ip=""
    
    public_ip=$(curl -s -m 5 https://ipinfo.io/ip 2>/dev/null || echo "")
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -s -m 5 https://ifconfig.me 2>/dev/null || echo "")
    fi
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -s -m 5 https://icanhazip.com 2>/dev/null | tr -d '\n' || echo "")
    fi
    if [ -z "$public_ip" ]; then
        public_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
    fi
    if [ -z "$public_ip" ]; then
        public_ip="localhost"
    fi
    
    echo "$public_ip"
}

show_connection_info() {
    local server_ip=$(get_public_ip)
    
    echo ""
    echo "==================================="
    echo "🚀 PostgreSQL Cluster Ready!"
    echo "==================================="
    echo ""
    echo "📋 Your Database Credentials:"
    echo "   Username: $DB_USER"
    echo "   Password: $DB_PASSWORD"
    echo "   Database: scaleddb"
    echo "   Server IP: $server_ip"
    echo ""
    echo "🔗 Primary Connection String (Read/Write):"
    echo "   postgresql://$DB_USER:$DB_PASSWORD@$server_ip:5432/scaleddb"
    echo ""
    echo "📖 Load Balanced Read Connection:"
    echo "   postgresql://$DB_USER:$DB_PASSWORD@$server_ip:5000/scaleddb"
    echo ""
    echo "🔧 Quick Connect Commands:"
    echo "   psql -h $server_ip -p 5432 -U $DB_USER -d scaleddb"
    echo "   psql -h $server_ip -p 5000 -U $DB_USER -d scaleddb  # Load balanced reads"
    echo ""
    echo "💾 Credentials saved to: env.local"
    echo "📊 HAProxy Stats: http://$server_ip:8080/stats (admin/admin)"
    echo "==================================="
}

case "$1" in
    start)
        echo "Starting PostgreSQL cluster..."
        
        # Generate credentials if not exists
        if [ ! -f env.local ]; then
            generate_credentials
        else
            echo "Loading existing credentials from env.local"
            source env.local
        fi
        
        # Start services
        docker compose up -d
        echo "Waiting for services to be healthy..."
        sleep 30
        
        # Show status
        docker compose ps
        
        # Wait a bit more for database to be fully ready
        echo "Waiting for database initialization..."
        sleep 15
        
        # Create the user
        create_user_in_db
        
        # Retry user creation if it failed (database might still be initializing)
        if ! docker exec postgres-primary psql -U postgres -d scaleddb -c "SELECT 1 FROM pg_user WHERE usename='$DB_USER';" | grep -q "1 row"; then
            echo "Retrying user creation..."
            sleep 10
            create_user_in_db
        fi
        
        # Show connection information
        show_connection_info
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
    credentials|creds)
        if [ -f env.local ]; then
            source env.local
            show_connection_info
        else
            echo "No credentials found. Run './manage.sh start' first to generate credentials."
        fi
        ;;
    clean)
        echo "Cleaning up PostgreSQL cluster and volumes..."
        docker compose down -v
        docker volume prune -f
        rm -f env.local
        echo "Credentials file removed."
        ;;
    *)
        echo "PostgreSQL Cluster Management"
        echo "Usage: $0 {start|stop|restart|status|logs|backup|connect|test|credentials|clean}"
        echo ""
        echo "Commands:"
        echo "  start          - Start cluster & create credentials with connection string"
        echo "  stop           - Stop the PostgreSQL cluster"
        echo "  restart        - Restart the PostgreSQL cluster"
        echo "  status         - Show cluster and replication status"
        echo "  logs [svc]     - Show logs (default: postgres-primary)"
        echo "  backup         - Create a database backup"
        echo "  connect [t]    - Connect to database (primary|replica1|replica2|pooler|read)"
        echo "  test           - Test cluster functionality"
        echo "  credentials    - Show connection strings for generated user"
        echo "  clean          - Stop cluster, remove volumes & credentials"
        echo ""
        echo "Get all connection strings with public IP:"
        echo "  ./get-connection-string.sh"
        echo ""
        echo "Examples:"
        echo "  $0 start                    # Start cluster with auto-generated credentials"
        echo "  $0 credentials              # Show connection info"
        echo "  $0 connect replica1         # Connect to specific replica"
        echo "  $0 logs postgres-replica-1  # View logs"
        exit 1
        ;;
esac
