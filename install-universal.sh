#!/bin/bash

# ExiledProjectCMS Universal Installation & Deployment Manager
# Version: 2.0.0
# Supports: Single-machine, Multi-machine SSH deployment, Health checks, Monitoring

set -euo pipefail

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Global configuration
readonly SCRIPT_VERSION="2.0.0"
readonly INSTALL_DIR="/opt/exiledproject-cms"
readonly SERVICE_USER="exiled"
readonly CONFIG_DIR="/etc/exiledproject-cms"
readonly LOG_FILE="/var/log/exiledproject-cms-install.log"
readonly INVENTORY_FILE="/var/lib/exiledproject-cms/deployment-inventory.json"

# Installation mode
INSTALLATION_MODE=""  # single, distributed, hybrid
SSH_KEY_PATH=""
SSH_USER="root"
MASTER_HOST=""
DEPLOYMENT_INVENTORY=()

# Component selection arrays
declare -A COMPONENTS=(
    [cms-api]="Main C# API Service"
    [go-api]="High-Performance Go API"
    [skins-service]="Minecraft Skins & Capes"
    [email-service]="Email Notification Service"
    [admin-panel]="Vue.js Admin Panel"
    [webapp]="Public Vue.js Website"
    [nginx]="Load Balancer & Reverse Proxy"
    [database]="Database Service"
    [redis]="Cache Service"
    [monitoring]="Prometheus + Grafana"
)

declare -A SELECTED_COMPONENTS
declare -A COMPONENT_HOSTS
declare -A COMPONENT_ACCESS

# Default access configurations
declare -A DEFAULT_ACCESS=(
    [database]="127.0.0.1"
    [redis]="master,apis"
    [cms-api]="0.0.0.0"
    [go-api]="0.0.0.0"
    [skins-service]="0.0.0.0"
    [email-service]="127.0.0.1"
    [admin-panel]="0.0.0.0"
    [webapp]="0.0.0.0"
    [nginx]="0.0.0.0"
    [monitoring]="master"
)

# Utility functions
log() {
    local level="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $*" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

print_banner() {
    clear
    cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║    🚀 ExiledProjectCMS Universal Deployment Manager       ║
║                                                            ║
║    ✨ Features:                                            ║
║    • Single-machine installation                          ║
║    • Multi-machine SSH deployment                         ║
║    • Component-based architecture                         ║
║    • Automated health checks                              ║
║    • Performance monitoring                               ║
║    • Security-focused access control                      ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "\n${GREEN}Version: $SCRIPT_VERSION${NC}"
    echo -e "${CYAN}Starting deployment process...${NC}\n"
}

print_step() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"

    while true; do
        if [ "$default" = "y" ]; then
            read -p "$prompt [Y/n]: " response
            response=${response:-y}
        else
            read -p "$prompt [y/N]: " response
            response=${response:-n}
        fi

        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Prerequisites check
check_prerequisites() {
    print_step "Checking prerequisites"

    local required_commands=("docker" "docker-compose" "curl" "jq" "ssh")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -gt 0 ]; then
        print_error "Missing required commands: ${missing_commands[*]}"
        echo "Please install missing dependencies and run the installer again."
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# SSH connection test
test_ssh_connection() {
    local host="$1"
    local user="${2:-$SSH_USER}"
    local key_path="${3:-$SSH_KEY_PATH}"

    local ssh_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes"

    if [[ -n "$key_path" && -f "$key_path" ]]; then
        ssh_opts="$ssh_opts -i $key_path"
    fi

    if ssh $ssh_opts "$user@$host" "echo 'SSH connection successful'" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Remote command execution
execute_remote() {
    local host="$1"
    local command="$2"
    local user="${3:-$SSH_USER}"
    local key_path="${4:-$SSH_KEY_PATH}"

    local ssh_opts="-o StrictHostKeyChecking=no"

    if [[ -n "$key_path" && -f "$key_path" ]]; then
        ssh_opts="$ssh_opts -i $key_path"
    fi

    ssh $ssh_opts "$user@$host" "$command"
}

# Installation mode selection
select_installation_mode() {
    print_step "Select Installation Mode"

    echo "Choose your deployment strategy:"
    echo ""
    echo "1) 🏠 Single Machine    - Install everything on current machine"
    echo "2) 🌐 Distributed      - Deploy components across multiple machines"
    echo "3) 🔄 Hybrid           - Mix of local and remote components"
    echo ""

    while true; do
        read -p "Select installation mode (1-3): " mode_choice
        case $mode_choice in
            1)
                INSTALLATION_MODE="single"
                MASTER_HOST="localhost"
                break
                ;;
            2)
                INSTALLATION_MODE="distributed"
                configure_ssh_settings
                break
                ;;
            3)
                INSTALLATION_MODE="hybrid"
                configure_ssh_settings
                break
                ;;
            *)
                echo "Invalid choice. Please select 1, 2, or 3."
                ;;
        esac
    done

    print_success "Installation mode: $INSTALLATION_MODE"
}

# SSH configuration
configure_ssh_settings() {
    print_step "Configure SSH Settings"

    read -p "SSH username [root]: " SSH_USER
    SSH_USER=${SSH_USER:-root}

    echo "SSH authentication method:"
    echo "1) SSH Key (recommended)"
    echo "2) Password (less secure)"

    while true; do
        read -p "Select authentication method (1-2): " auth_choice
        case $auth_choice in
            1)
                read -p "SSH private key path [~/.ssh/id_rsa]: " SSH_KEY_PATH
                SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_rsa}
                SSH_KEY_PATH=$(eval echo "$SSH_KEY_PATH")

                if [[ ! -f "$SSH_KEY_PATH" ]]; then
                    print_error "SSH key file not found: $SSH_KEY_PATH"
                    exit 1
                fi
                break
                ;;
            2)
                print_warning "Password authentication will be prompted for each connection"
                SSH_KEY_PATH=""
                break
                ;;
            *)
                echo "Invalid choice. Please select 1 or 2."
                ;;
        esac
    done

    read -p "Master host IP/hostname: " MASTER_HOST

    # Test SSH connection to master
    print_step "Testing SSH connection to master host"
    if test_ssh_connection "$MASTER_HOST"; then
        print_success "SSH connection to master host successful"
    else
        print_error "Failed to connect to master host via SSH"
        if ask_yes_no "Continue anyway? (manual installation required)"; then
            print_warning "Manual installation mode enabled"
        else
            exit 1
        fi
    fi
}

# Component selection
select_components() {
    print_step "Select Components to Install"

    echo "Available components:"
    echo ""

    local i=1
    local component_keys=()
    for component in "${!COMPONENTS[@]}"; do
        echo "$i) ${COMPONENTS[$component]} [$component]"
        component_keys+=("$component")
        ((i++))
    done

    echo ""
    echo "Select components (comma-separated numbers, or 'all' for everything):"
    read -p "Selection: " selection

    if [[ "$selection" == "all" ]]; then
        for component in "${!COMPONENTS[@]}"; do
            SELECTED_COMPONENTS[$component]=true
        done
    else
        IFS=',' read -ra selected_nums <<< "$selection"
        for num in "${selected_nums[@]}"; do
            num=$(echo "$num" | xargs)  # trim whitespace
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#component_keys[@]}" ]; then
                local idx=$((num - 1))
                local component="${component_keys[$idx]}"
                SELECTED_COMPONENTS[$component]=true
            fi
        done
    fi

    # Show selected components
    echo ""
    echo "Selected components:"
    for component in "${!SELECTED_COMPONENTS[@]}"; do
        echo "  ✓ ${COMPONENTS[$component]} [$component]"
    done
}

# Host assignment for distributed installation
assign_component_hosts() {
    if [[ "$INSTALLATION_MODE" == "single" ]]; then
        for component in "${!SELECTED_COMPONENTS[@]}"; do
            COMPONENT_HOSTS[$component]="localhost"
        done
        return
    fi

    print_step "Assign Components to Hosts"

    for component in "${!SELECTED_COMPONENTS[@]}"; do
        echo ""
        echo "Component: ${COMPONENTS[$component]} [$component]"

        if [[ "$INSTALLATION_MODE" == "hybrid" ]]; then
            if ask_yes_no "Install $component locally?"; then
                COMPONENT_HOSTS[$component]="localhost"
                continue
            fi
        fi

        while true; do
            read -p "Host for $component [$MASTER_HOST]: " host
            host=${host:-$MASTER_HOST}

            if [[ "$host" == "localhost" ]]; then
                COMPONENT_HOSTS[$component]="localhost"
                break
            fi

            print_step "Testing SSH connection to $host"
            if test_ssh_connection "$host"; then
                COMPONENT_HOSTS[$component]="$host"
                print_success "Host assigned: $host"
                break
            else
                print_error "Cannot connect to $host"
                if ask_yes_no "Try a different host?"; then
                    continue
                else
                    COMPONENT_HOSTS[$component]="manual:$host"
                    print_warning "Host $host marked for manual installation"
                    break
                fi
            fi
        done
    done
}

# Security and access configuration
configure_access_control() {
    print_step "Configure Access Control"

    echo "Configuring network access for components..."
    echo ""

    for component in "${!SELECTED_COMPONENTS[@]}"; do
        local default_access="${DEFAULT_ACCESS[$component]:-0.0.0.0}"

        echo "Component: ${COMPONENTS[$component]} [$component]"
        echo "Default access: $default_access"
        echo "Options:"
        echo "  127.0.0.1      - Localhost only"
        echo "  master         - Master host only"
        echo "  0.0.0.0        - All interfaces"
        echo "  custom         - Custom IP/CIDR"

        read -p "Access configuration [$default_access]: " access_config
        access_config=${access_config:-$default_access}

        COMPONENT_ACCESS[$component]="$access_config"
    done
}

# Environment preparation
prepare_env_vars() {
    print_step "Preparing environment variables"

    # Ensure config directory exists
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true

    # Defaults
    DB_PROVIDER=${DATABASE_PROVIDER:-MySQL}
    DB_NAME=${DB_NAME:-ExiledProjectCMS}
    DB_USER=${DB_USER:-exiled}
    DB_PASSWORD=${DB_PASSWORD:-ExiledPass123!}
    DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-ExiledStrong123!}
    REDIS_PASSWORD=${REDIS_PASSWORD:-ExiledRedis123!}

    # Compose service hostnames (local compose network)
    local db_host="mysql"
    local db_port="3306"
    local redis_host="redis"
    local redis_port="6379"

    # Build connection strings for supported providers
    case "${DB_PROVIDER,,}" in
        mysql)
            DB_CONNECTION_STRING="Server=${db_host};Port=${db_port};Database=${DB_NAME};User=${DB_USER};Password=${DB_PASSWORD};SslMode=None;"
            GO_DB_CONNECTION_STRING="${DB_USER}:${DB_PASSWORD}@tcp(${db_host}:${db_port})/${DB_NAME}?parseTime=true&charset=utf8mb4,utf8"
            ;;
        mariadb)
            DB_CONNECTION_STRING="Server=${db_host};Port=${db_port};Database=${DB_NAME};User=${DB_USER};Password=${DB_PASSWORD};SslMode=None;"
            GO_DB_CONNECTION_STRING="${DB_USER}:${DB_PASSWORD}@tcp(${db_host}:${db_port})/${DB_NAME}?parseTime=true&charset=utf8mb4,utf8"
            ;;
        postgres|postgresql)
            # Note: C# provider name may differ elsewhere; here we only build conn strings
            db_port="5432"
            DB_CONNECTION_STRING="Host=${db_host};Port=${db_port};Database=${DB_NAME};Username=${DB_USER};Password=${DB_PASSWORD};"
            GO_DB_CONNECTION_STRING="postgres://${DB_USER}:${DB_PASSWORD}@${db_host}:${db_port}/${DB_NAME}?sslmode=disable"
            ;;
        sqlserver|mssql)
            db_port="1433"
            DB_CONNECTION_STRING="Server=${db_host},${db_port};Database=${DB_NAME};User Id=${DB_USER};Password=${DB_PASSWORD};TrustServerCertificate=True;"
            GO_DB_CONNECTION_STRING="sqlserver://${DB_USER}:${DB_PASSWORD}@${db_host}:${db_port}?database=${DB_NAME}"
            ;;
        *)
            print_warning "Unknown DATABASE_PROVIDER '${DB_PROVIDER}', defaulting to MySQL-style strings"
            DB_CONNECTION_STRING="Server=${db_host};Port=${db_port};Database=${DB_NAME};User=${DB_USER};Password=${DB_PASSWORD};SslMode=None;"
            GO_DB_CONNECTION_STRING="${DB_USER}:${DB_PASSWORD}@tcp(${db_host}:${db_port})/${DB_NAME}?parseTime=true&charset=utf8mb4,utf8"
            ;;
    esac

    REDIS_CONNECTION_STRING="${redis_host}:${redis_port},password=${REDIS_PASSWORD}"

    # Export to environment for immediate use by compose generation
    export DATABASE_PROVIDER="$DB_PROVIDER"
    export DB_CONNECTION_STRING
    export GO_DB_CONNECTION_STRING
    export REDIS_CONNECTION_STRING
    export DB_NAME DB_USER DB_PASSWORD DB_ROOT_PASSWORD REDIS_PASSWORD

    # Also persist to a .env file next to compose for user visibility
    local env_file=".env.generated"
    cat > "$env_file" <<EOF
# Generated by install-universal.sh v$SCRIPT_VERSION
DATABASE_PROVIDER=$DB_PROVIDER
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
DB_CONNECTION_STRING=$DB_CONNECTION_STRING
GO_DB_CONNECTION_STRING=$GO_DB_CONNECTION_STRING
REDIS_CONNECTION_STRING=$REDIS_CONNECTION_STRING
EOF
    print_success "Environment prepared and saved to $env_file"
}

# Generate Docker Compose configuration
generate_docker_compose() {
    print_step "Generating Docker Compose Configuration"

    local compose_file="docker-compose.generated.yml"

    cat > "$compose_file" << 'EOF'
version: '3.8'

services:
EOF

    # Add selected services to compose file
    for component in "${!SELECTED_COMPONENTS[@]}"; do
        local host="${COMPONENT_HOSTS[$component]}"
        local access="${COMPONENT_ACCESS[$component]}"

        case $component in
            "database")
                add_database_service >> "$compose_file"
                ;;
            "redis")
                add_redis_service >> "$compose_file"
                ;;
            "cms-api")
                add_cms_api_service >> "$compose_file"
                ;;
            "go-api")
                add_go_api_service >> "$compose_file"
                ;;
            "skins-service")
                add_skins_service >> "$compose_file"
                ;;
            "email-service")
                add_email_service >> "$compose_file"
                ;;
            "nginx")
                add_nginx_service >> "$compose_file"
                ;;
            "monitoring")
                add_monitoring_services >> "$compose_file"
                ;;
        esac
    done

    # Add networks and volumes
    cat >> "$compose_file" << 'EOF'

networks:
  exiled-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  mysql_data:
  postgres_data:
  redis_data:
  prometheus_data:
  grafana_data:
EOF

    print_success "Docker Compose configuration generated: $compose_file"
}

# Individual service generators
add_database_service() {
    cat << 'EOF'
  mysql:
    image: mysql:8.0
    container_name: exiled-mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-ExiledStrong123!}
      - MYSQL_DATABASE=${DB_NAME:-ExiledProjectCMS}
      - MYSQL_USER=${DB_USER:-exiled}
      - MYSQL_PASSWORD=${DB_PASSWORD:-ExiledPass123!}
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - exiled-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 5

EOF
}

add_redis_service() {
    cat << 'EOF'
  redis:
    image: redis:7-alpine
    container_name: exiled-redis
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD:-ExiledRedis123!}
    volumes:
      - redis_data:/data
    networks:
      - exiled-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

EOF
}

add_cms_api_service() {
    cat << 'EOF'
  cms-api:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: exiled-cms-api
    environment:
      - ASPNETCORE_ENVIRONMENT=${ENVIRONMENT:-Production}
      - ASPNETCORE_URLS=http://+:80
      - DatabaseProvider=${DATABASE_PROVIDER:-MySQL}
      - CacheProvider=${CACHE_PROVIDER:-Redis}
      - ConnectionStrings__DefaultConnection=${DB_CONNECTION_STRING}
      - ConnectionStrings__Redis=${REDIS_CONNECTION_STRING}
    depends_on:
      - mysql
      - redis
    networks:
      - exiled-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/health"]
      interval: 30s
      timeout: 10s
      retries: 5

EOF
}

add_go_api_service() {
    cat << 'EOF'
  go-api:
    build:
      context: ./GoServices/HighPerformanceAPI
      dockerfile: Dockerfile
    container_name: exiled-go-api
    environment:
      - GO_API_PORT=8080
      - DATABASE_PROVIDER=${DATABASE_PROVIDER:-mysql}
      - DATABASE_URL=${GO_DB_CONNECTION_STRING}
      - REDIS_URL=redis:6379
    depends_on:
      - mysql
      - redis
    networks:
      - exiled-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 5

EOF
}

add_skins_service() {
    cat << 'EOF'
  skins-service:
    build:
      context: ./GoServices/SkinsCapesService
      dockerfile: Dockerfile
    container_name: exiled-skins-service
    environment:
      - SKINS_CAPES_PORT=8081
      - DATABASE_PROVIDER=${DATABASE_PROVIDER:-MySQL}
      - DB_CONNECTION_STRING=${DB_CONNECTION_STRING}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=${REDIS_PASSWORD:-ExiledRedis123!}
    volumes:
      - ./storage/skins:/app/storage/skins
    depends_on:
      - mysql
      - redis
    networks:
      - exiled-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8081/health"]
      interval: 30s
      timeout: 10s
      retries: 5

EOF
}

add_email_service() {
    cat << 'EOF'
  email-service:
    build:
      context: ./GoServices/EmailService
      dockerfile: Dockerfile
    container_name: exiled-email-service
    environment:
      - EMAIL_SERVICE_PORT=8082
      - SMTP_HOST=${SMTP_HOST:-smtp.gmail.com}
      - SMTP_PORT=${SMTP_PORT:-587}
      - SMTP_USERNAME=${SMTP_USERNAME}
      - SMTP_PASSWORD=${SMTP_PASSWORD}
      - SMTP_FROM=${SMTP_FROM}
    depends_on:
      - redis
    networks:
      - exiled-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8082/health"]
      interval: 30s
      timeout: 10s
      retries: 5

EOF
}

add_nginx_service() {
    cat << 'EOF'
  nginx:
    image: nginx:alpine
    container_name: exiled-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - cms-api
      - go-api
    networks:
      - exiled-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:80/health"]
      interval: 30s
      timeout: 10s
      retries: 5

EOF
}

add_monitoring_services() {
    cat << 'EOF'
  prometheus:
    image: prom/prometheus:latest
    container_name: exiled-prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    networks:
      - exiled-network

  grafana:
    image: grafana/grafana:latest
    container_name: exiled-grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD:-admin}
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/var/lib/grafana/dashboards
    depends_on:
      - prometheus
    networks:
      - exiled-network

EOF
}

# Deployment execution
execute_deployment() {
    print_step "Executing Deployment"

    mkdir -p "$(dirname "$INVENTORY_FILE")"

    # Initialize inventory
    echo '{"deployment_info":{"timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","mode":"'$INSTALLATION_MODE'","version":"'$SCRIPT_VERSION'"},"components":{}}' > "$INVENTORY_FILE"

    for component in "${!SELECTED_COMPONENTS[@]}"; do
        local host="${COMPONENT_HOSTS[$component]}"
        local access="${COMPONENT_ACCESS[$component]}"

        print_step "Deploying $component to $host"

        if [[ "$host" == "localhost" ]]; then
            deploy_component_local "$component"
        elif [[ "$host" == manual:* ]]; then
            local actual_host="${host#manual:}"
            print_warning "Manual deployment required for $component on $actual_host"
            create_manual_deployment_instructions "$component" "$actual_host"
        else
            deploy_component_remote "$component" "$host"
        fi

        # Update inventory
        update_deployment_inventory "$component" "$host" "$access"
    done

    # Start services
    start_all_services
}

# Local deployment
deploy_component_local() {
    local component="$1"

    case $component in
        "cms-api"|"go-api"|"skins-service"|"email-service")
            docker-compose -f docker-compose.generated.yml build "$component" || true
            ;;
        "database"|"redis"|"nginx"|"monitoring")
            # These are pulled images, no build needed
            ;;
    esac

    log_info "Component $component deployed locally"
}

# Remote deployment
deploy_component_remote() {
    local component="$1"
    local host="$2"

    print_step "Copying files to $host"

    # Create temporary deployment package
    local temp_dir=$(mktemp -d)
    cp -r . "$temp_dir/exiled-cms"

    # Copy to remote host
    if [[ -n "$SSH_KEY_PATH" ]]; then
        scp -i "$SSH_KEY_PATH" -r "$temp_dir/exiled-cms" "$SSH_USER@$host:/tmp/"
    else
        scp -r "$temp_dir/exiled-cms" "$SSH_USER@$host:/tmp/"
    fi

    # Execute remote installation
    local remote_script="
        cd /tmp/exiled-cms
        docker-compose -f docker-compose.generated.yml build $component 2>/dev/null || true
        echo 'Component $component deployed on $host'
    "

    execute_remote "$host" "$remote_script"

    # Cleanup
    rm -rf "$temp_dir"

    log_info "Component $component deployed to $host"
}

# Manual deployment instructions
create_manual_deployment_instructions() {
    local component="$1"
    local host="$2"

    local instructions_file="manual-deployment-$component-$host.md"

    cat > "$instructions_file" << EOF
# Manual Deployment Instructions

## Component: $component
## Target Host: $host

### Prerequisites
1. Install Docker and Docker Compose on the target host
2. Copy project files to the target host
3. Configure environment variables

### Deployment Steps
1. Copy this project to the target host:
   \`\`\`bash
   scp -r . user@$host:/opt/exiledproject-cms/
   \`\`\`

2. SSH into the target host:
   \`\`\`bash
   ssh user@$host
   cd /opt/exiledproject-cms
   \`\`\`

3. Deploy the component:
   \`\`\`bash
   docker-compose -f docker-compose.generated.yml up -d $component
   \`\`\`

### Verification
Run health check:
\`\`\`bash
docker-compose -f docker-compose.generated.yml ps $component
\`\`\`

Generated on: $(date)
EOF

    print_warning "Manual deployment instructions created: $instructions_file"
}

# Update deployment inventory
update_deployment_inventory() {
    local component="$1"
    local host="$2"
    local access="$3"

    # Update JSON inventory using jq
    local temp_file=$(mktemp)
    jq ".components.\"$component\" = {\"host\": \"$host\", \"access\": \"$access\", \"status\": \"deployed\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" "$INVENTORY_FILE" > "$temp_file"
    mv "$temp_file" "$INVENTORY_FILE"
}

# Start all services
start_all_services() {
    print_step "Starting All Services"

    if [[ "$INSTALLATION_MODE" == "single" ]]; then
        docker-compose -f docker-compose.generated.yml up -d
        print_success "All services started locally"
    else
        # Start services on each host
        local hosts=($(printf '%s\n' "${COMPONENT_HOSTS[@]}" | sort -u))

        for host in "${hosts[@]}"; do
            if [[ "$host" == "localhost" ]]; then
                docker-compose -f docker-compose.generated.yml up -d
            elif [[ "$host" != manual:* ]]; then
                execute_remote "$host" "cd /tmp/exiled-cms && docker-compose -f docker-compose.generated.yml up -d"
            fi
        done

        print_success "Services started on all hosts"
    fi

    # Wait for services to be ready
    sleep 30
}

# Health check functions
check_service_health() {
    local service="$1"
    local host="${2:-localhost}"
    local port="$3"
    local path="${4:-/health}"

    local url="http://$host:$port$path"
    local max_attempts=5
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            return 0
        fi

        sleep 5
        ((attempt++))
    done

    return 1
}

# Performance benchmarking
benchmark_api_performance() {
    local api_url="$1"
    local service_name="$2"

    print_step "Benchmarking $service_name performance"

    # Simple response time test
    local response_time=$(curl -o /dev/null -s -w '%{time_total}\n' "$api_url")
    local http_code=$(curl -o /dev/null -s -w '%{http_code}\n' "$api_url")

    echo "  Response Time: ${response_time}s"
    echo "  HTTP Code: $http_code"

    # Load test with multiple requests
    echo "  Running load test (10 concurrent requests)..."
    local load_test_result=$(seq 1 10 | xargs -n1 -P10 -I{} curl -o /dev/null -s -w '%{time_total}\n' "$api_url" | awk '{sum+=$1; count++} END {print "Average:", sum/count, "Max:", max, "Min:", min}' max=0 min=999)
    echo "  Load Test Result: $load_test_result"
}

# Comprehensive health check
run_health_checks() {
    print_step "Running Comprehensive Health Checks"

    local health_report_file="health-report-$(date +%Y%m%d-%H%M%S).json"
    echo '{"timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","checks":{}}' > "$health_report_file"

    # Check each deployed component
    for component in "${!SELECTED_COMPONENTS[@]}"; do
        local host="${COMPONENT_HOSTS[$component]}"
        local access="${COMPONENT_ACCESS[$component]}"

        print_step "Health check: $component on $host"

        local health_status="unknown"
        local response_time="0"

        case $component in
            "cms-api")
                local api_url="http://$host:5006/health"
                if check_service_health "cms-api" "$host" "5006"; then
                    health_status="healthy"
                    benchmark_api_performance "$api_url" "CMS API"
                else
                    health_status="unhealthy"
                fi
                ;;
            "go-api")
                local api_url="http://$host:8080/health"
                if check_service_health "go-api" "$host" "8080"; then
                    health_status="healthy"
                    benchmark_api_performance "$api_url" "Go API"
                else
                    health_status="unhealthy"
                fi
                ;;
            "skins-service")
                local api_url="http://$host:8081/health"
                if check_service_health "skins-service" "$host" "8081"; then
                    health_status="healthy"
                    benchmark_api_performance "$api_url" "Skins Service"
                else
                    health_status="unhealthy"
                fi
                ;;
            "database")
                # Database health check via Docker
                if docker-compose -f docker-compose.generated.yml exec -T mysql mysqladmin ping -h localhost &> /dev/null; then
                    health_status="healthy"
                else
                    health_status="unhealthy"
                fi
                ;;
            "redis")
                # Redis health check
                if docker-compose -f docker-compose.generated.yml exec -T redis redis-cli ping &> /dev/null; then
                    health_status="healthy"
                else
                    health_status="unhealthy"
                fi
                ;;
            "nginx")
                local api_url="http://$host:80"
                if check_service_health "nginx" "$host" "80" "/"; then
                    health_status="healthy"
                    benchmark_api_performance "$api_url" "Load Balancer"
                else
                    health_status="unhealthy"
                fi
                ;;
        esac

        # Update health report
        local temp_file=$(mktemp)
        jq ".checks.\"$component\" = {\"host\": \"$host\", \"status\": \"$health_status\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" "$health_report_file" > "$temp_file"
        mv "$temp_file" "$health_report_file"

        if [[ "$health_status" == "healthy" ]]; then
            print_success "$component is healthy"
        else
            print_error "$component is unhealthy"
        fi
    done

    print_success "Health check completed. Report: $health_report_file"
}

# Generate deployment summary
generate_deployment_summary() {
    print_step "Generating Deployment Summary"

    local summary_file="deployment-summary-$(date +%Y%m%d-%H%M%S).md"

    cat > "$summary_file" << EOF
# ExiledProjectCMS Deployment Summary

**Generated:** $(date)
**Mode:** $INSTALLATION_MODE
**Version:** $SCRIPT_VERSION

## Deployed Components

EOF

    for component in "${!SELECTED_COMPONENTS[@]}"; do
        local host="${COMPONENT_HOSTS[$component]}"
        local access="${COMPONENT_ACCESS[$component]}"

        cat >> "$summary_file" << EOF
### ${COMPONENTS[$component]}
- **Component ID:** $component
- **Host:** $host
- **Access:** $access
- **Status:** Deployed

EOF
    done

    cat >> "$summary_file" << EOF

## Access Information

EOF

    # Add access URLs based on deployed components
    if [[ -n "${SELECTED_COMPONENTS[cms-api]}" ]]; then
        local host="${COMPONENT_HOSTS[cms-api]}"
        echo "- **Main API:** http://$host:5006" >> "$summary_file"
        echo "- **API Documentation:** http://$host:5006/swagger" >> "$summary_file"
    fi

    if [[ -n "${SELECTED_COMPONENTS[go-api]}" ]]; then
        local host="${COMPONENT_HOSTS[go-api]}"
        echo "- **Go API:** http://$host:8080" >> "$summary_file"
    fi

    if [[ -n "${SELECTED_COMPONENTS[admin-panel]}" ]]; then
        local host="${COMPONENT_HOSTS[admin-panel]}"
        echo "- **Admin Panel:** http://$host:3000" >> "$summary_file"
    fi

    if [[ -n "${SELECTED_COMPONENTS[nginx]}" ]]; then
        local host="${COMPONENT_HOSTS[nginx]}"
        echo "- **Load Balancer:** http://$host:80" >> "$summary_file"
    fi

    cat >> "$summary_file" << EOF

## Management Commands

\`\`\`bash
# View deployment inventory
cat $INVENTORY_FILE | jq

# Check service status
docker-compose -f docker-compose.generated.yml ps

# View logs
docker-compose -f docker-compose.generated.yml logs -f [service]

# Restart services
docker-compose -f docker-compose.generated.yml restart

# Stop services
docker-compose -f docker-compose.generated.yml down

# Update and redeploy
git pull && ./install-universal.sh
\`\`\`

## Files Generated

- **Docker Compose:** docker-compose.generated.yml
- **Deployment Inventory:** $INVENTORY_FILE
- **Health Reports:** health-report-*.json
- **Manual Instructions:** manual-deployment-*.md (if any)

---
*Generated by ExiledProjectCMS Universal Installer v$SCRIPT_VERSION*
EOF

    print_success "Deployment summary generated: $summary_file"
}

# Main installation flow
main() {
    print_banner

    log_info "Starting ExiledProjectCMS Universal Installation"

    # Checks
    check_prerequisites

    # Configuration
    select_installation_mode
    select_components
    assign_component_hosts
    configure_access_control

    # Deployment
    prepare_env_vars
    generate_docker_compose
    execute_deployment

    # Verification
    run_health_checks

    # Documentation
    generate_deployment_summary

    print_success "🎉 ExiledProjectCMS deployment completed successfully!"

    echo ""
    echo -e "${CYAN}📋 Next Steps:${NC}"
    echo "1. Review the deployment summary for access URLs"
    echo "2. Check the health report for any issues"
    echo "3. Configure SSL certificates for production use"
    echo "4. Set up monitoring and alerting"
    echo "5. Backup your configuration files"

    log_info "Installation completed successfully"
}

# Trap for cleanup
cleanup() {
    log_info "Installation interrupted. Cleaning up..."
    # Add any cleanup operations here
    exit 1
}

trap cleanup INT TERM

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi