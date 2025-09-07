#!/bin/bash

# PostgreSQL Connection String Generator with Public IP

set -e

# Function to get public IP
get_public_ip() {
    # Try multiple services in case one is down
    local public_ip=""
    
    # Try ipinfo.io first
    public_ip=$(curl -s -m 5 https://ipinfo.io/ip 2>/dev/null || echo "")
    
    # Fallback to ifconfig.me
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -s -m 5 https://ifconfig.me 2>/dev/null || echo "")
    fi
    
    # Fallback to icanhazip.com
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -s -m 5 https://icanhazip.com 2>/dev/null | tr -d '\n' || echo "")
    fi
    
    # If all external services fail, try local network detection
    if [ -z "$public_ip" ]; then
        public_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
    fi
    
    # Final fallback
    if [ -z "$public_ip" ]; then
        public_ip="localhost"
    fi
    
    echo "$public_ip"
}

# Database connection parameters
DB_NAME="scaleddb"
DB_USER="postgres"
DB_PASSWORD="postgres123"

# Get public IP
PUBLIC_IP=$(get_public_ip)

echo "=== PostgreSQL Connection Strings ==="
echo "Server Public IP: $PUBLIC_IP"
echo ""

case "${1:-all}" in
    primary|write)
        echo "=== PRIMARY DATABASE (Read/Write) ==="
        echo "Host: $PUBLIC_IP"
        echo "Port: 5432"
        echo "Connection String:"
        echo "postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5432/$DB_NAME"
        echo ""
        echo "psql Command:"
        echo "psql -h $PUBLIC_IP -p 5432 -U $DB_USER -d $DB_NAME"
        ;;
    replica1)
        echo "=== REPLICA 1 (Read-Only) ==="
        echo "Host: $PUBLIC_IP"
        echo "Port: 5433"
        echo "Connection String:"
        echo "postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5433/$DB_NAME"
        echo ""
        echo "psql Command:"
        echo "psql -h $PUBLIC_IP -p 5433 -U $DB_USER -d $DB_NAME"
        ;;
    replica2)
        echo "=== REPLICA 2 (Read-Only) ==="
        echo "Host: $PUBLIC_IP"
        echo "Port: 5434"
        echo "Connection String:"
        echo "postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5434/$DB_NAME"
        echo ""
        echo "psql Command:"
        echo "psql -h $PUBLIC_IP -p 5434 -U $DB_USER -d $DB_NAME"
        ;;
    pooler|pgbouncer)
        echo "=== PGBOUNCER CONNECTION POOLER ==="
        echo "Host: $PUBLIC_IP"
        echo "Port: 6432"
        echo "Connection String:"
        echo "postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:6432/$DB_NAME"
        echo ""
        echo "psql Command:"
        echo "psql -h $PUBLIC_IP -p 6432 -U $DB_USER -d $DB_NAME"
        ;;
    read|load-balanced)
        echo "=== LOAD BALANCED READ QUERIES ==="
        echo "Host: $PUBLIC_IP"
        echo "Port: 5000"
        echo "Connection String:"
        echo "postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5000/$DB_NAME"
        echo ""
        echo "psql Command:"
        echo "psql -h $PUBLIC_IP -p 5000 -U $DB_USER -d $DB_NAME"
        ;;
    write-only)
        echo "=== WRITE-ONLY ENDPOINT ==="
        echo "Host: $PUBLIC_IP"
        echo "Port: 5001"
        echo "Connection String:"
        echo "postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5001/$DB_NAME"
        echo ""
        echo "psql Command:"
        echo "psql -h $PUBLIC_IP -p 5001 -U $DB_USER -d $DB_NAME"
        ;;
    env)
        echo "=== ENVIRONMENT VARIABLES ==="
        echo "export PGHOST=$PUBLIC_IP"
        echo "export PGPORT=5432"
        echo "export PGUSER=$DB_USER"
        echo "export PGPASSWORD=$DB_PASSWORD"
        echo "export PGDATABASE=$DB_NAME"
        echo ""
        echo "# For read operations (load balanced)"
        echo "export PGHOST_READ=$PUBLIC_IP"
        echo "export PGPORT_READ=5000"
        echo ""
        echo "# For pooled connections"
        echo "export PGHOST_POOLED=$PUBLIC_IP"
        echo "export PGPORT_POOLED=6432"
        ;;
    json)
        echo "{"
        echo "  \"server_ip\": \"$PUBLIC_IP\","
        echo "  \"database\": \"$DB_NAME\","
        echo "  \"username\": \"$DB_USER\","
        echo "  \"connections\": {"
        echo "    \"primary\": {"
        echo "      \"host\": \"$PUBLIC_IP\","
        echo "      \"port\": 5432,"
        echo "      \"connection_string\": \"postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5432/$DB_NAME\""
        echo "    },"
        echo "    \"replica1\": {"
        echo "      \"host\": \"$PUBLIC_IP\","
        echo "      \"port\": 5433,"
        echo "      \"connection_string\": \"postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5433/$DB_NAME\""
        echo "    },"
        echo "    \"replica2\": {"
        echo "      \"host\": \"$PUBLIC_IP\","
        echo "      \"port\": 5434,"
        echo "      \"connection_string\": \"postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5434/$DB_NAME\""
        echo "    },"
        echo "    \"pooler\": {"
        echo "      \"host\": \"$PUBLIC_IP\","
        echo "      \"port\": 6432,"
        echo "      \"connection_string\": \"postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:6432/$DB_NAME\""
        echo "    },"
        echo "    \"read_balanced\": {"
        echo "      \"host\": \"$PUBLIC_IP\","
        echo "      \"port\": 5000,"
        echo "      \"connection_string\": \"postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5000/$DB_NAME\""
        echo "    },"
        echo "    \"write_only\": {"
        echo "      \"host\": \"$PUBLIC_IP\","
        echo "      \"port\": 5001,"
        echo "      \"connection_string\": \"postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5001/$DB_NAME\""
        echo "    }"
        echo "  }"
        echo "}"
        ;;
    all|*)
        echo "=== ALL CONNECTION ENDPOINTS ==="
        echo ""
        echo "PRIMARY DATABASE (Read/Write):"
        echo "  Connection: postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5432/$DB_NAME"
        echo "  psql: psql -h $PUBLIC_IP -p 5432 -U $DB_USER -d $DB_NAME"
        echo ""
        echo "REPLICA 1 (Read-Only):"
        echo "  Connection: postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5433/$DB_NAME"
        echo "  psql: psql -h $PUBLIC_IP -p 5433 -U $DB_USER -d $DB_NAME"
        echo ""
        echo "REPLICA 2 (Read-Only):"
        echo "  Connection: postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5434/$DB_NAME"
        echo "  psql: psql -h $PUBLIC_IP -p 5434 -U $DB_USER -d $DB_NAME"
        echo ""
        echo "PGBOUNCER CONNECTION POOLER:"
        echo "  Connection: postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:6432/$DB_NAME"
        echo "  psql: psql -h $PUBLIC_IP -p 6432 -U $DB_USER -d $DB_NAME"
        echo ""
        echo "LOAD BALANCED READ QUERIES:"
        echo "  Connection: postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5000/$DB_NAME"
        echo "  psql: psql -h $PUBLIC_IP -p 5000 -U $DB_USER -d $DB_NAME"
        echo ""
        echo "WRITE-ONLY ENDPOINT:"
        echo "  Connection: postgresql://$DB_USER:$DB_PASSWORD@$PUBLIC_IP:5001/$DB_NAME"
        echo "  psql: psql -h $PUBLIC_IP -p 5001 -U $DB_USER -d $DB_NAME"
        echo ""
        echo "HAPROXY STATS:"
        echo "  URL: http://$PUBLIC_IP:8080/stats"
        echo "  Credentials: admin/admin"
        ;;
esac

if [ "${1:-all}" = "all" ] || [ -z "$1" ]; then
    echo ""
    echo "=== USAGE ==="
    echo "Get specific connection:"
    echo "  $0 primary      # Primary database"
    echo "  $0 replica1     # First replica"
    echo "  $0 replica2     # Second replica"  
    echo "  $0 pooler       # PgBouncer pooled connection"
    echo "  $0 read         # Load balanced read endpoint"
    echo "  $0 write-only   # Write-only endpoint"
    echo "  $0 env          # Environment variables"
    echo "  $0 json         # JSON format"
fi
