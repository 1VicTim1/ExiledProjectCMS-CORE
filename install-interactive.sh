#!/bin/bash

# ExiledProjectCMS Interactive Installer
# Advanced modular installation with component selection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Global variables
INSTALL_DIR="/opt/exiledproject-cms"
SERVICE_USER="exiled"
CONFIG_DIR="/etc/exiledproject-cms"
LOG_FILE="/var/log/exiledproject-cms-install.log"
COMPOSE_FILE="docker-compose.generated.yml"
ENV_FILE=".env"
ENV_FILE_PROVIDED=0

# Configuration arrays
SELECTED_COMPONENTS=()
EXTERNAL_SERVICES=()

# Functions
init_logging() {
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || true
    fi
    # Fallback to local log if not writable
    if ! touch "$LOG_FILE" 2>/dev/null; then
        LOG_FILE="./install.log"
        touch "$LOG_FILE" 2>/dev/null || true
    fi
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --env-file)
                shift
                ENV_FILE="$1"
                ENV_FILE_PROVIDED=1
                ;;
            --log-file)
                shift
                LOG_FILE="$1"
                ;;
            --help|-h)
                echo "Usage: $0 [--env-file <path>] [--log-file <path>]"
                exit 0
                ;;
        esac
        shift || true
    done
}

print_banner() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}${CYAN}${BOLD}       ExiledProjectCMS Interactive Installer       ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${YELLOW}        Advanced Modular Installation System         ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}This installer will guide you through a custom installation${NC}"
    echo -e "${GREEN}where you can choose exactly what components to install.${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response

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

select_database() {
    echo -e "\n${CYAN}${BOLD}=== DATABASE CONFIGURATION ===${NC}"
    echo "Choose your database setup:"
    echo ""
    echo "1) Install MySQL locally (Docker container)"
    echo "2) Install PostgreSQL locally (Docker container)"
    echo "3) Install SQL Server locally (Docker container)"
    echo "4) Use external MySQL database"
    echo "5) Use external PostgreSQL database"
    echo "6) Use external SQL Server database"
    echo ""

    while true; do
        read -p "Select database option (1-6): " db_choice
        case $db_choice in
            1)
                DATABASE_PROVIDER="MySQL"
                SELECTED_COMPONENTS+=("database-mysql")
                break
                ;;
            2)
                DATABASE_PROVIDER="PostgreSQL"
                SELECTED_COMPONENTS+=("database-postgres")
                break
                ;;
            3)
                DATABASE_PROVIDER="SqlServer"
                SELECTED_COMPONENTS+=("database-sqlserver")
                break
                ;;
            4)
                DATABASE_PROVIDER="MySQL"
                EXTERNAL_SERVICES+=("mysql")
                configure_external_database "mysql"
                break
                ;;
            5)
                DATABASE_PROVIDER="PostgreSQL"
                EXTERNAL_SERVICES+=("postgres")
                configure_external_database "postgres"
                break
                ;;
            6)
                DATABASE_PROVIDER="SqlServer"
                EXTERNAL_SERVICES+=("sqlserver")
                configure_external_database "sqlserver"
                break
                ;;
            *)
                echo "Invalid choice. Please select 1-6."
                ;;
        esac
    done

    echo -e "${GREEN}✓ Database: $DATABASE_PROVIDER${NC}"
}

configure_external_database() {
    local db_type="$1"
    echo -e "\n${YELLOW}Configuring external $db_type database:${NC}"

    read -p "Database host: " DB_HOST
    read -p "Database port [default]: " DB_PORT
    read -p "Database name: " DB_NAME
    read -p "Database username: " DB_USER
    read -s -p "Database password: " DB_PASSWORD
    echo ""

    case $db_type in
        mysql)
            DB_PORT=${DB_PORT:-3306}
            DB_CONNECTION_STRING="Server=${DB_HOST};Port=${DB_PORT};Database=${DB_NAME};Uid=${DB_USER};Pwd=${DB_PASSWORD};"
            GO_DB_CONNECTION_STRING="${DB_USER}:${DB_PASSWORD}@tcp(${DB_HOST}:${DB_PORT})/${DB_NAME}?charset=utf8mb4&parseTime=True&loc=Local"
            ;;
        postgres)
            DB_PORT=${DB_PORT:-5432}
            DB_CONNECTION_STRING="Host=${DB_HOST};Port=${DB_PORT};Database=${DB_NAME};Username=${DB_USER};Password=${DB_PASSWORD};"
            GO_DB_CONNECTION_STRING="postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable"
            ;;
        sqlserver)
            DB_PORT=${DB_PORT:-1433}
            DB_CONNECTION_STRING="Server=${DB_HOST},${DB_PORT};Database=${DB_NAME};User Id=${DB_USER};Password=${DB_PASSWORD};TrustServerCertificate=true;"
            GO_DB_CONNECTION_STRING="sqlserver://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}?database=${DB_NAME}"
            ;;
    esac
}

select_cache() {
    echo -e "\n${CYAN}${BOLD}=== CACHE CONFIGURATION ===${NC}"
    echo "Choose your caching setup:"
    echo ""
    echo "1) Memory cache only (single instance, development)"
    echo "2) Install Redis locally (Docker container)"
    echo "3) Use external Redis server"
    echo ""

    while true; do
        read -p "Select cache option (1-3): " cache_choice
        case $cache_choice in
            1)
                CACHE_PROVIDER="Memory"
                REDIS_CONNECTION_STRING=""
                break
                ;;
            2)
                CACHE_PROVIDER="Redis"
                SELECTED_COMPONENTS+=("cache-redis")
                REDIS_CONNECTION_STRING="redis:6379,password=\${REDIS_PASSWORD}"
                break
                ;;
            3)
                CACHE_PROVIDER="Redis"
                EXTERNAL_SERVICES+=("redis")
                configure_external_redis
                break
                ;;
            *)
                echo "Invalid choice. Please select 1-3."
                ;;
        esac
    done

    echo -e "${GREEN}✓ Cache: $CACHE_PROVIDER${NC}"
}

configure_external_redis() {
    echo -e "\n${YELLOW}Configuring external Redis:${NC}"

    read -p "Redis host: " REDIS_HOST
    read -p "Redis port [6379]: " REDIS_PORT
    REDIS_PORT=${REDIS_PORT:-6379}
    read -s -p "Redis password (leave empty if none): " REDIS_PASSWORD
    echo ""

    if [ -n "$REDIS_PASSWORD" ]; then
        REDIS_CONNECTION_STRING="${REDIS_HOST}:${REDIS_PORT},password=${REDIS_PASSWORD}"
    else
        REDIS_CONNECTION_STRING="${REDIS_HOST}:${REDIS_PORT}"
    fi
}

select_services() {
    echo -e "\n${CYAN}${BOLD}=== SERVICES CONFIGURATION ===${NC}"
    echo "Choose which services to install:"
    echo ""

    # High-performance Go API
    if ask_yes_no "Install High-Performance Go API? (recommended for production)" "y"; then
        SELECTED_COMPONENTS+=("services-go")
        echo -e "${GREEN}✓ Go API will be installed${NC}"
    fi

    # Skins & Capes service
    if ask_yes_no "Install Skins & Capes service? (for Minecraft skins support)" "y"; then
        SELECTED_COMPONENTS+=("services-skins")
        echo -e "${GREEN}✓ Skins & Capes service will be installed${NC}"

        # S3 Storage configuration for skins
        if ask_yes_no "Use AWS S3 for skins storage? (otherwise local storage)" "n"; then
            configure_s3_storage
        fi
    fi

    # Email service
    if ask_yes_no "Install Email service?" "y"; then
        SELECTED_COMPONENTS+=("services-email")
        configure_email_service
        echo -e "${GREEN}✓ Email service will be installed${NC}"
    fi

    # Frontend
    if ask_yes_no "Install Frontend (Admin Panel + Website)?" "y"; then
        SELECTED_COMPONENTS+=("frontend")
        echo -e "${GREEN}✓ Frontend will be installed${NC}"
    fi

    # Load Balancer
    if ask_yes_no "Install Nginx Load Balancer?" "y"; then
        SELECTED_COMPONENTS+=("loadbalancer")
        echo -e "${GREEN}✓ Nginx Load Balancer will be installed${NC}"
    fi
}

configure_s3_storage() {
    echo -e "\n${YELLOW}Configuring AWS S3 storage:${NC}"

    read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
    read -s -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    echo ""
    read -p "AWS Region [us-east-1]: " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    read -p "S3 Bucket name: " AWS_S3_BUCKET

    STORAGE_PROVIDER="s3"
}

configure_email_service() {
    echo -e "\n${YELLOW}Configuring Email service:${NC}"

    read -p "SMTP Host (e.g., smtp.gmail.com): " SMTP_HOST
    read -p "SMTP Port [587]: " SMTP_PORT
    SMTP_PORT=${SMTP_PORT:-587}
    read -p "SMTP Username: " SMTP_USERNAME
    read -s -p "SMTP Password: " SMTP_PASSWORD
    echo ""
    read -p "From Email Address: " SMTP_FROM

    if ask_yes_no "Use TLS encryption?" "y"; then
        SMTP_USE_TLS="true"
    else
        SMTP_USE_TLS="false"
    fi
}

select_monitoring() {
    echo -e "\n${CYAN}${BOLD}=== MONITORING CONFIGURATION ===${NC}"

    if ask_yes_no "Install monitoring stack (Prometheus + Grafana)?" "n"; then
        SELECTED_COMPONENTS+=("monitoring")

        echo -e "\n${YELLOW}Configuring Grafana:${NC}"
        read -p "Grafana admin username [admin]: " GRAFANA_ADMIN_USER
        GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}

        while true; do
            read -s -p "Grafana admin password (min 8 characters): " GRAFANA_PASSWORD
            echo ""
            if [[ ${#GRAFANA_PASSWORD} -ge 8 ]]; then
                break
            else
                print_error "Password must be at least 8 characters long"
            fi
        done

        echo -e "${GREEN}✓ Monitoring stack will be installed${NC}"
    fi
}

configure_admin_user() {
    echo -e "\n${CYAN}${BOLD}=== ADMIN USER CONFIGURATION ===${NC}"

    read -p "Admin username [admin]: " ADMIN_USERNAME
    ADMIN_USERNAME=${ADMIN_USERNAME:-admin}

    read -p "Admin email [admin@example.com]: " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}

    read -p "Admin display name [Super Admin]: " ADMIN_DISPLAY_NAME
    ADMIN_DISPLAY_NAME=${ADMIN_DISPLAY_NAME:-Super Admin}

    while true; do
        read -s -p "Admin password (min 8 characters): " ADMIN_PASSWORD
        echo ""
        if [[ ${#ADMIN_PASSWORD} -ge 8 ]]; then
            break
        else
            print_error "Password must be at least 8 characters long"
        fi
    done

    echo -e "${GREEN}✓ Admin user configured${NC}"
}

configure_security() {
    echo -e "\n${CYAN}${BOLD}=== SECURITY CONFIGURATION ===${NC}"

    # Generate secure random keys if not provided
    if [ -z "$JWT_SECRET" ]; then
        JWT_SECRET=$(openssl rand -base64 32)
        echo -e "${GREEN}✓ JWT secret generated${NC}"
    fi

    if [ -z "$ENCRYPTION_KEY" ]; then
        ENCRYPTION_KEY=$(openssl rand -base64 24)
        echo -e "${GREEN}✓ Encryption key generated${NC}"
    fi

    # Domain configuration
    read -p "Domain name (for SSL configuration) [localhost]: " DOMAIN_NAME
    DOMAIN_NAME=${DOMAIN_NAME:-localhost}

    if [ "$DOMAIN_NAME" != "localhost" ]; then
        if ask_yes_no "Configure SSL certificates?" "y"; then
            configure_ssl
        fi
    fi
}

configure_ssl() {
    echo -e "\n${YELLOW}SSL Configuration:${NC}"
    echo "1) Generate self-signed certificates"
    echo "2) Use existing certificates"
    echo "3) Use Let's Encrypt (automatic)"

    while true; do
        read -p "Select SSL option (1-3): " ssl_choice
        case $ssl_choice in
            1)
                SSL_MODE="self-signed"
                break
                ;;
            2)
                SSL_MODE="existing"
                read -p "Path to SSL certificate file: " SSL_CERT_PATH
                read -p "Path to SSL private key file: " SSL_KEY_PATH
                break
                ;;
            3)
                SSL_MODE="letsencrypt"
                read -p "Email for Let's Encrypt: " LETSENCRYPT_EMAIL
                break
                ;;
            *)
                echo "Invalid choice. Please select 1-3."
                ;;
        esac
    done
}

generate_docker_compose() {
    print_step "Generating Docker Compose configuration..."

    # Start with base template
    cat docker-templates/base.yml > $COMPOSE_FILE

    # Add network definition to all additional templates
    for component in "${SELECTED_COMPONENTS[@]}"; do
        # Guard: skip frontend if source directories are missing to avoid build errors
        if [ "$component" = "frontend" ]; then
            if [ ! -d "Frontend/admin-panel" ] && [ ! -d "Frontend/webapp" ]; then
                print_warning "Frontend sources not found (Frontend/admin-panel or Frontend/webapp). Skipping frontend component."
                continue
            fi
        fi
        echo -e "\n# === $component ===" >> $COMPOSE_FILE
        # Remove version and networks section from component files, keep only services and volumes
        sed '/^version:/d; /^networks:/,/^$/d; /^$/N;/^\n$/d' docker-templates/${component}.yml >> $COMPOSE_FILE
    done

    # Add networks section at the end
    echo -e "\n# === NETWORKS ===" >> $COMPOSE_FILE
    echo "networks:" >> $COMPOSE_FILE
    echo "  exiled-network:" >> $COMPOSE_FILE
    echo "    driver: bridge" >> $COMPOSE_FILE
    echo "    ipam:" >> $COMPOSE_FILE
    echo "      config:" >> $COMPOSE_FILE
    echo "        - subnet: 172.20.0.0/16" >> $COMPOSE_FILE

    print_success "Docker Compose configuration generated: $COMPOSE_FILE"
}

generate_env_file() {
    print_step "Generating environment configuration..."

    # If a custom env file was provided and exists, do not overwrite
    if [ -f "$ENV_FILE" ] && [ "$ENV_FILE_PROVIDED" -eq 1 ]; then
        print_warning "Environment file already exists at $ENV_FILE. Using existing file."
        log "Using existing env file: $ENV_FILE"
        return 0
    fi

    cat > "$ENV_FILE" << EOF
# ExiledProjectCMS Environment Configuration
# Generated by Interactive Installer on $(date)

# ===========================================
# APPLICATION SETTINGS
# ===========================================
ENVIRONMENT=production
APPLICATION_NAME=ExiledProjectCMS
DOMAIN_NAME=$DOMAIN_NAME

# ===========================================
# DATABASE CONFIGURATION
# ===========================================
DATABASE_PROVIDER=$DATABASE_PROVIDER
DB_NAME=${DB_NAME:-ExiledProjectCMS}
DB_USER=${DB_USER:-exiled}
DB_PASSWORD=${DB_PASSWORD:-$(openssl rand -base64 16)}
DB_SA_PASSWORD=${DB_SA_PASSWORD:-$(openssl rand -base64 16)Strong!}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-$(openssl rand -base64 16)Root!}

# Connection strings
DB_CONNECTION_STRING=${DB_CONNECTION_STRING}
GO_DB_CONNECTION_STRING=${GO_DB_CONNECTION_STRING}

# Database ports
SQLSERVER_PORT=${SQLSERVER_PORT:-1433}
MYSQL_PORT=${MYSQL_PORT:-3306}
POSTGRES_PORT=${POSTGRES_PORT:-5432}

# ===========================================
# CACHE CONFIGURATION
# ===========================================
CACHE_PROVIDER=$CACHE_PROVIDER
REDIS_HOST=${REDIS_HOST:-redis}
REDIS_PASSWORD=${REDIS_PASSWORD:-$(openssl rand -base64 16)}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_DATABASE=0
REDIS_CONNECTION_STRING=${REDIS_CONNECTION_STRING}

# ===========================================
# API CONFIGURATION
# ===========================================
API_PORT=${API_PORT:-5006}
GO_API_PORT=${GO_API_PORT:-8080}
SKINS_CAPES_PORT=${SKINS_CAPES_PORT:-8081}
EMAIL_SERVICE_PORT=${EMAIL_SERVICE_PORT:-8082}

# API Scaling
API_REPLICAS=${API_REPLICAS:-1}
GO_API_REPLICAS=${GO_API_REPLICAS:-2}
SKINS_CAPES_REPLICAS=${SKINS_CAPES_REPLICAS:-1}
EMAIL_SERVICE_REPLICAS=${EMAIL_SERVICE_REPLICAS:-1}

# ===========================================
# FRONTEND CONFIGURATION
# ===========================================
ADMIN_PORT=${ADMIN_PORT:-3000}
WEBAPP_PORT=${WEBAPP_PORT:-8090}
WEBAPP_REPLICAS=${WEBAPP_REPLICAS:-2}

# API Base URLs for frontend
API_BASE_URL=http://$DOMAIN_NAME:5006
GO_API_BASE_URL=http://$DOMAIN_NAME:8080
SKINS_API_BASE_URL=http://$DOMAIN_NAME:8081

# ===========================================
# LOAD BALANCER & PROXY
# ===========================================
HTTP_PORT=${HTTP_PORT:-80}
HTTPS_PORT=${HTTPS_PORT:-443}
SSL_CERTS_PATH=${SSL_CERTS_PATH:-./ssl}

# ===========================================
# ADMIN USER
# ===========================================
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD
ADMIN_DISPLAY_NAME=$ADMIN_DISPLAY_NAME

# ===========================================
# SECURITY & SSL
# ===========================================
JWT_SECRET=$JWT_SECRET
ENCRYPTION_KEY=$ENCRYPTION_KEY
SSL_MODE=${SSL_MODE:-none}
SSL_CERT_PATH=${SSL_CERT_PATH}
SSL_KEY_PATH=${SSL_KEY_PATH}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}

# ===========================================
# EMAIL CONFIGURATION
# ===========================================
SMTP_HOST=${SMTP_HOST}
SMTP_PORT=${SMTP_PORT}
SMTP_USERNAME=${SMTP_USERNAME}
SMTP_PASSWORD=${SMTP_PASSWORD}
SMTP_FROM=${SMTP_FROM}
SMTP_USE_TLS=${SMTP_USE_TLS:-true}

# ===========================================
# STORAGE CONFIGURATION
# ===========================================
STORAGE_PROVIDER=${STORAGE_PROVIDER:-local}
SKINS_STORAGE_PATH=${SKINS_STORAGE_PATH:-./storage/skins}
BASE_URL=http://$DOMAIN_NAME

# AWS S3 Configuration
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_REGION=${AWS_REGION}
AWS_S3_BUCKET=${AWS_S3_BUCKET}

# ===========================================
# MONITORING CONFIGURATION
# ===========================================
PROMETHEUS_PORT=${PROMETHEUS_PORT:-9090}
PROMETHEUS_RETENTION=${PROMETHEUS_RETENTION:-15d}
GRAFANA_PORT=${GRAFANA_PORT:-3001}
GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER}
GRAFANA_PASSWORD=${GRAFANA_PASSWORD}

# ===========================================
# LOGGING
# ===========================================
LOG_LEVEL=Information
LOG_FILE_PATH=/app/Logs/exiled-cms.log
LOG_MAX_SIZE=100MB

# ===========================================
# PERFORMANCE SETTINGS
# ===========================================
CACHE_DEFAULT_EXPIRATION=1800
CACHE_NEWS_EXPIRATION=900
CACHE_USERS_EXPIRATION=3600
RATE_LIMIT_REQUESTS_PER_MINUTE=60
RATE_LIMIT_BURST=10

# ===========================================
# DEVELOPMENT SETTINGS
# ===========================================
DEBUG_MODE=false
ENABLE_SWAGGER=true
ENABLE_CORS=true
ENABLE_PLUGIN_HOT_RELOAD=true

EOF

    chmod 600 "$ENV_FILE"
    print_success "Environment file generated: $ENV_FILE"
}

show_installation_summary() {
    echo -e "\n${CYAN}${BOLD}=== INSTALLATION SUMMARY ===${NC}"
    echo -e "${YELLOW}The following components will be installed:${NC}"
    echo ""

    echo -e "${GREEN}✓ ExiledProjectCMS API (C#)${NC} - Main application"

    for component in "${SELECTED_COMPONENTS[@]}"; do
        case $component in
            database-mysql) echo -e "${GREEN}✓ MySQL Database${NC} - Local Docker container" ;;
            database-postgres) echo -e "${GREEN}✓ PostgreSQL Database${NC} - Local Docker container" ;;
            database-sqlserver) echo -e "${GREEN}✓ SQL Server Database${NC} - Local Docker container" ;;
            cache-redis) echo -e "${GREEN}✓ Redis Cache${NC} - Local Docker container" ;;
            services-go) echo -e "${GREEN}✓ High-Performance Go API${NC} - Enhanced performance" ;;
            services-skins) echo -e "${GREEN}✓ Skins & Capes Service${NC} - Minecraft assets" ;;
            services-email) echo -e "${GREEN}✓ Email Service${NC} - Email notifications" ;;
            frontend) echo -e "${GREEN}✓ Frontend Applications${NC} - Admin Panel + Website" ;;
            loadbalancer) echo -e "${GREEN}✓ Nginx Load Balancer${NC} - Reverse proxy" ;;
            monitoring) echo -e "${GREEN}✓ Monitoring Stack${NC} - Prometheus + Grafana" ;;
        esac
    done

    if [ ${#EXTERNAL_SERVICES[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}External services configured:${NC}"
        for service in "${EXTERNAL_SERVICES[@]}"; do
            echo -e "${BLUE}→ External $service${NC}"
        done
    fi

    echo -e "\n${CYAN}Database:${NC} $DATABASE_PROVIDER"
    echo -e "${CYAN}Cache:${NC} $CACHE_PROVIDER"
    echo -e "${CYAN}Domain:${NC} $DOMAIN_NAME"

    echo ""
    if ask_yes_no "Proceed with installation?" "y"; then
        return 0
    else
        print_warning "Installation cancelled by user"
        exit 0
    fi
}

check_prerequisites() {
    print_step "Checking prerequisites..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    # Check if Docker Compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi

    # Check if running as root or in docker group
    if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        print_error "Please run as root or add your user to the docker group"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

install_system() {
    print_step "Starting ExiledProjectCMS installation..."

    # Create necessary directories
    mkdir -p ssl logs storage/skins Plugins Uploads nginx/conf.d monitoring/grafana/dashboards scripts

    # Prepare monitoring configuration files if monitoring stack is selected
    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " monitoring " ]]; then
        print_step "Preparing monitoring configuration files..."
        # Ensure required directories exist
        mkdir -p monitoring \
                 monitoring/grafana/dashboards \
                 monitoring/grafana/provisioning/datasources \
                 monitoring/grafana/provisioning/dashboards

        # Create default Prometheus configuration if missing
        if [ ! -f monitoring/prometheus.yml ]; then
            cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'exiled-api'
    static_configs:
      - targets: ['api:5006']

  - job_name: 'go-api'
    static_configs:
      - targets: ['go-api:8080']

  - job_name: 'skins-capes'
    static_configs:
      - targets: ['skins-capes:8081']
EOF
        fi

        # Create Grafana datasource provisioning for Prometheus if missing
        if [ ! -f monitoring/grafana/provisioning/datasources/datasource.yml ]; then
            cat > monitoring/grafana/provisioning/datasources/datasource.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOF
        fi

        # Create Grafana dashboards provider if missing
        if [ ! -f monitoring/grafana/provisioning/dashboards/dashboard.yml ]; then
            cat > monitoring/grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF
        fi

        print_success "Monitoring configuration prepared"
    fi

    # Generate SSL certificates if needed
    if [ "$SSL_MODE" = "self-signed" ]; then
        print_step "Generating self-signed SSL certificates..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/server.key \
            -out ssl/server.crt \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN_NAME"
        print_success "SSL certificates generated"
    fi

    # Start services
    print_step "Starting Docker services..."

    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    else
        docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    fi

    # Wait for services to be ready
    print_step "Waiting for services to start..."
    sleep 30

    # Test services
    print_step "Testing service health..."

    max_attempts=30
    attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s http://localhost:${API_PORT:-5006}/health > /dev/null; then
            print_success "Main API is healthy"
            break
        fi

        attempt=$((attempt + 1))
        if [ $attempt -eq $max_attempts ]; then
            print_warning "Main API health check failed, but continuing..."
        else
            echo "Waiting for API to be ready... (attempt $attempt/$max_attempts)"
            sleep 10
        fi
    done

    print_success "ExiledProjectCMS installation completed!"
}

show_completion_info() {
    echo -e "\n${GREEN}${BOLD}🎉 ExiledProjectCMS installation completed successfully!${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}=== ACCESS INFORMATION ===${NC}"

    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " frontend " ]]; then
        echo -e "${GREEN}Admin Panel:${NC}     http://$DOMAIN_NAME:${ADMIN_PORT:-3000}"
        echo -e "${GREEN}Website:${NC}         http://$DOMAIN_NAME:${WEBAPP_PORT:-8090}"
    fi

    echo -e "${GREEN}Main API:${NC}        http://$DOMAIN_NAME:${API_PORT:-5006}"

    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " services-go " ]]; then
        echo -e "${GREEN}Go API:${NC}          http://$DOMAIN_NAME:${GO_API_PORT:-8080}"
    fi

    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " services-skins " ]]; then
        echo -e "${GREEN}Skins API:${NC}       http://$DOMAIN_NAME:${SKINS_CAPES_PORT:-8081}"
    fi

    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " loadbalancer " ]]; then
        echo -e "${GREEN}Load Balancer:${NC}   http://$DOMAIN_NAME:${HTTP_PORT:-80}"
    fi

    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " monitoring " ]]; then
        echo -e "${GREEN}Prometheus:${NC}      http://$DOMAIN_NAME:${PROMETHEUS_PORT:-9090}"
        echo -e "${GREEN}Grafana:${NC}         http://$DOMAIN_NAME:${GRAFANA_PORT:-3001}"
    fi

    echo ""
    echo -e "${CYAN}${BOLD}=== ADMIN CREDENTIALS ===${NC}"
    echo -e "${GREEN}Username:${NC}        $ADMIN_USERNAME"
    echo -e "${GREEN}Email:${NC}           $ADMIN_EMAIL"
    echo -e "${GREEN}Password:${NC}        [as configured]"

    echo ""
    echo -e "${CYAN}${BOLD}=== MANAGEMENT COMMANDS ===${NC}"
    echo -e "${GREEN}Start services:${NC}   docker-compose -f $COMPOSE_FILE --env-file \"$ENV_FILE\" up -d"
    echo -e "${GREEN}Stop services:${NC}    docker-compose -f $COMPOSE_FILE --env-file \"$ENV_FILE\" down"
    echo -e "${GREEN}View logs:${NC}        docker-compose -f $COMPOSE_FILE --env-file \"$ENV_FILE\" logs -f"
    echo -e "${GREEN}Update system:${NC}    git pull && docker-compose -f $COMPOSE_FILE --env-file \"$ENV_FILE\" build --pull"

        echo ""
        echo -e "${YELLOW}Tip:${NC} If you start services manually, use: docker-compose -f $COMPOSE_FILE --env-file \"$ENV_FILE\" up -d"
        echo ""
        echo -e "${CYAN}${BOLD}=== CONFIGURATION FILES ===${NC}"
        echo -e "${GREEN}Environment:${NC}      $ENV_FILE"
        echo -e "${GREEN}Docker Compose:${NC}   $COMPOSE_FILE"
        echo -e "${GREEN}Installation log:${NC} $LOG_FILE"

        echo ""
        echo -e "${YELLOW}${BOLD}Important Notes:${NC}"
        echo -e "${YELLOW}• Please backup your environment file ($ENV_FILE) - it contains sensitive information${NC}"
    echo -e "${YELLOW}• Change default passwords in production environments${NC}"
    echo -e "${YELLOW}• Configure firewall rules for your selected services${NC}"
    if [ "$SSL_MODE" = "self-signed" ]; then
        echo -e "${YELLOW}• Replace self-signed certificates with proper SSL certificates${NC}"
    fi
    echo ""
}

main() {
    parse_args "$@"
    init_logging
    log "Starting ExiledProjectCMS Interactive Installation"
    log "Using env file: $ENV_FILE"
    log "Log file: $LOG_FILE"

    print_banner

    check_prerequisites
    select_database
    select_cache
    select_services
    select_monitoring
    configure_admin_user
    configure_security

    show_installation_summary

    generate_docker_compose
    generate_env_file

    install_system
    show_completion_info

    log "Installation completed successfully"
}

# Trap to ensure cleanup on exit
trap 'echo -e "\n${RED}Installation interrupted${NC}"; exit 1' INT TERM

# Run main function
main "$@"