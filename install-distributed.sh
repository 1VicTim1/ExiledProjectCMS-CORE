#!/bin/bash

# ExiledProjectCMS Distributed Interactive Installer
# Advanced multi-machine deployment with service discovery

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Global configuration
SWARM_NETWORK="exiled-distributed"
STACK_NAME="exiledproject-cms"
CONFIG_DIR="./distributed-config"
NODES_CONFIG="$CONFIG_DIR/nodes.json"
SERVICES_CONFIG="$CONFIG_DIR/services.json"

# Service definitions
declare -A SERVICES=(
    ["database"]="Base de données (MySQL/PostgreSQL/SQL Server)"
    ["redis"]="Cache Redis"
    ["cms-api"]="API Principal C#"
    ["go-api"]="API High-Performance Go"
    ["skins-service"]="Service Skins & Capes"
    ["email-service"]="Service Email"
    ["frontend"]="Frontend (Admin + Website)"
    ["loadbalancer"]="Load Balancer Nginx"
    ["monitoring"]="Monitoring (Prometheus + Grafana)"
)

# Machine roles
declare -A MACHINE_ROLES=(
    ["database"]="Serveur de base de données"
    ["cache"]="Serveur de cache"
    ["api"]="Serveur API"
    ["frontend"]="Serveur Frontend"
    ["loadbalancer"]="Load Balancer"
    ["monitoring"]="Monitoring"
    ["worker"]="Worker générique"
)

print_banner() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}${CYAN}${BOLD}    ExiledProjectCMS Distributed Installer         ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${YELLOW}       Advanced Multi-Machine Deployment             ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Configure services across multiple machines with intelligent${NC}"
    echo -e "${GREEN}service discovery and automatic network configuration.${NC}"
    echo ""
}

print_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

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

setup_directories() {
    print_step "Setting up configuration directories..."
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR/certificates"
    mkdir -p "$CONFIG_DIR/nginx"
    mkdir -p "$CONFIG_DIR/monitoring"
    print_success "Directories created"
}

discover_machines() {
    print_step "Machine Discovery and Configuration"
    echo ""
    echo -e "${CYAN}We'll configure machines for each service type.${NC}"
    echo -e "${CYAN}You can use the same machine for multiple services.${NC}"
    echo ""

    # Initialize machines array
    declare -A MACHINES
    local machine_count=0

    echo -e "${BOLD}Available machine roles:${NC}"
    for role in "${!MACHINE_ROLES[@]}"; do
        echo -e "  ${GREEN}$role${NC}: ${MACHINE_ROLES[$role]}"
    done
    echo ""

    # Ask for machines
    while true; do
        echo -e "${CYAN}Machine #$((machine_count + 1)):${NC}"
        read -p "Machine IP/hostname: " machine_ip

        if [ -z "$machine_ip" ]; then
            if [ $machine_count -eq 0 ]; then
                print_error "You need at least one machine"
                continue
            else
                break
            fi
        fi

        read -p "Machine name/description: " machine_name
        machine_name=${machine_name:-"machine-$((machine_count + 1))"}

        # Test connectivity
        print_step "Testing connectivity to $machine_ip..."
        if ping -c 1 -W 1 "$machine_ip" &>/dev/null; then
            print_success "Machine $machine_ip is reachable"
        else
            print_warning "Machine $machine_ip is not reachable (continuing anyway)"
        fi

        # Select roles for this machine
        echo ""
        echo "Select roles for $machine_name ($machine_ip):"
        declare -a selected_roles=()

        for role in "${!MACHINE_ROLES[@]}"; do
            if ask_yes_no "  Install $role on this machine?"; then
                selected_roles+=("$role")
            fi
        done

        if [ ${#selected_roles[@]} -eq 0 ]; then
            selected_roles+=("worker")
            print_warning "No specific role selected, assigned as worker"
        fi

        # Store machine configuration
        MACHINES["machine_${machine_count}"]=$(printf '%s|%s|%s' "$machine_ip" "$machine_name" "$(IFS=,; echo "${selected_roles[*]}")")

        echo -e "${GREEN}✓ Configured: $machine_name ($machine_ip) - Roles: $(IFS=,; echo "${selected_roles[*]}")${NC}"
        machine_count=$((machine_count + 1))

        echo ""
        if ! ask_yes_no "Add another machine?"; then
            break
        fi
        echo ""
    done

    # Save machines configuration
    echo "{" > "$NODES_CONFIG"
    echo "  \"machines\": {" >> "$NODES_CONFIG"

    local first=true
    for key in "${!MACHINES[@]}"; do
        if [ "$first" = false ]; then
            echo "," >> "$NODES_CONFIG"
        fi
        first=false

        IFS='|' read -r ip name roles <<< "${MACHINES[$key]}"
        echo -n "    \"$key\": {\"ip\": \"$ip\", \"name\": \"$name\", \"roles\": [" >> "$NODES_CONFIG"

        IFS=',' read -ra role_array <<< "$roles"
        for i, role in "${role_array[@]}"; do
            if [ $i -gt 0 ]; then echo -n ", " >> "$NODES_CONFIG"; fi
            echo -n "\"$role\"" >> "$NODES_CONFIG"
        done
        echo -n "]}" >> "$NODES_CONFIG"
    done

    echo "" >> "$NODES_CONFIG"
    echo "  }," >> "$NODES_CONFIG"
    echo "  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" >> "$NODES_CONFIG"
    echo "}" >> "$NODES_CONFIG"

    print_success "Machine discovery completed - saved to $NODES_CONFIG"
}

configure_services() {
    print_step "Service Configuration"
    echo ""
    echo -e "${CYAN}Now let's configure which services to deploy and where.${NC}"
    echo ""

    # Read machines from config
    if [ ! -f "$NODES_CONFIG" ]; then
        print_error "No machines configuration found. Run discovery first."
        exit 1
    fi

    declare -A SERVICE_PLACEMENT
    declare -A SERVICE_CONFIGS

    echo -e "${BOLD}Available services:${NC}"
    for service in "${!SERVICES[@]}"; do
        echo -e "  ${GREEN}$service${NC}: ${SERVICES[$service]}"
    done
    echo ""

    # Configure each service
    for service in "${!SERVICES[@]}"; do
        echo -e "\n${CYAN}=== Configuring $service ===${NC}"

        if ask_yes_no "Deploy $service?" "y"; then
            # Show available machines for this service
            echo "Available machines:"
            local machine_num=1
            while read -r line; do
                if echo "$line" | grep -q '"ip"'; then
                    local ip=$(echo "$line" | grep -o '"ip": *"[^"]*"' | cut -d'"' -f4)
                    local name=$(echo "$line" | grep -o '"name": *"[^"]*"' | cut -d'"' -f4)
                    echo "  $machine_num) $name ($ip)"
                    machine_num=$((machine_num + 1))
                fi
            done < "$NODES_CONFIG"

            read -p "Select machine number for $service: " machine_choice
            # Here you would map the choice to actual machine and validate

            # Service-specific configuration
            case $service in
                "database")
                    configure_database_service
                    ;;
                "redis")
                    configure_redis_service
                    ;;
                "cms-api"|"go-api")
                    configure_api_service "$service"
                    ;;
                "skins-service")
                    configure_skins_service
                    ;;
                "email-service")
                    configure_email_service
                    ;;
                "frontend")
                    configure_frontend_service
                    ;;
                "loadbalancer")
                    configure_loadbalancer_service
                    ;;
                "monitoring")
                    configure_monitoring_service
                    ;;
            esac

            SERVICE_PLACEMENT["$service"]="machine_$((machine_choice - 1))"
            echo -e "${GREEN}✓ $service configured${NC}"
        fi
    done
}

configure_database_service() {
    echo -e "\n${YELLOW}Database Configuration:${NC}"
    echo "1) PostgreSQL (recommended)"
    echo "2) MySQL"
    echo "3) SQL Server"
    read -p "Select database type (1-3) [1]: " db_choice
    db_choice=${db_choice:-1}

    case $db_choice in
        1) db_type="postgresql" ;;
        2) db_type="mysql" ;;
        3) db_type="sqlserver" ;;
    esac

    read -p "Database name [ExiledProjectCMS]: " db_name
    db_name=${db_name:-ExiledProjectCMS}

    read -p "Database username [exiled]: " db_user
    db_user=${db_user:-exiled}

    read -s -p "Database password: " db_password
    echo ""

    SERVICE_CONFIGS["database"]=$(printf '%s|%s|%s|%s' "$db_type" "$db_name" "$db_user" "$db_password")
}

configure_redis_service() {
    echo -e "\n${YELLOW}Redis Configuration:${NC}"
    read -s -p "Redis password: " redis_password
    echo ""

    read -p "Redis database number [0]: " redis_db
    redis_db=${redis_db:-0}

    SERVICE_CONFIGS["redis"]=$(printf '%s|%s' "$redis_password" "$redis_db")
}

configure_api_service() {
    local service="$1"
    echo -e "\n${YELLOW}$service Configuration:${NC}"

    read -p "Number of replicas [2]: " replicas
    replicas=${replicas:-2}

    read -p "Memory limit (e.g., 512M, 1G) [512M]: " memory_limit
    memory_limit=${memory_limit:-512M}

    SERVICE_CONFIGS["$service"]=$(printf '%s|%s' "$replicas" "$memory_limit")
}

configure_skins_service() {
    echo -e "\n${YELLOW}Skins & Capes Service Configuration:${NC}"

    if ask_yes_no "Use AWS S3 for storage?" "n"; then
        read -p "AWS Access Key ID: " aws_access_key
        read -s -p "AWS Secret Access Key: " aws_secret_key
        echo ""
        read -p "S3 Bucket name: " s3_bucket
        read -p "AWS Region [us-east-1]: " aws_region
        aws_region=${aws_region:-us-east-1}

        SERVICE_CONFIGS["skins-service"]=$(printf 's3|%s|%s|%s|%s' "$aws_access_key" "$aws_secret_key" "$s3_bucket" "$aws_region")
    else
        read -p "Local storage path [/app/storage/skins]: " storage_path
        storage_path=${storage_path:-/app/storage/skins}
        SERVICE_CONFIGS["skins-service"]=$(printf 'local|%s' "$storage_path")
    fi
}

configure_email_service() {
    echo -e "\n${YELLOW}Email Service Configuration:${NC}"

    read -p "SMTP Host: " smtp_host
    read -p "SMTP Port [587]: " smtp_port
    smtp_port=${smtp_port:-587}

    read -p "SMTP Username: " smtp_username
    read -s -p "SMTP Password: " smtp_password
    echo ""

    read -p "From email address: " smtp_from

    if ask_yes_no "Use TLS?" "y"; then
        smtp_tls="true"
    else
        smtp_tls="false"
    fi

    SERVICE_CONFIGS["email-service"]=$(printf '%s|%s|%s|%s|%s|%s' "$smtp_host" "$smtp_port" "$smtp_username" "$smtp_password" "$smtp_from" "$smtp_tls")
}

configure_frontend_service() {
    echo -e "\n${YELLOW}Frontend Configuration:${NC}"

    read -p "Admin panel port [3000]: " admin_port
    admin_port=${admin_port:-3000}

    read -p "Website port [8090]: " webapp_port
    webapp_port=${webapp_port:-8090}

    read -p "Number of website replicas [2]: " webapp_replicas
    webapp_replicas=${webapp_replicas:-2}

    SERVICE_CONFIGS["frontend"]=$(printf '%s|%s|%s' "$admin_port" "$webapp_port" "$webapp_replicas")
}

configure_loadbalancer_service() {
    echo -e "\n${YELLOW}Load Balancer Configuration:${NC}"

    read -p "HTTP port [80]: " http_port
    http_port=${http_port:-80}

    read -p "HTTPS port [443]: " https_port
    https_port=${https_port:-443}

    if ask_yes_no "Configure SSL certificates?" "y"; then
        read -p "SSL certificate path: " ssl_cert_path
        read -p "SSL private key path: " ssl_key_path
        SERVICE_CONFIGS["loadbalancer"]=$(printf '%s|%s|%s|%s' "$http_port" "$https_port" "$ssl_cert_path" "$ssl_key_path")
    else
        SERVICE_CONFIGS["loadbalancer"]=$(printf '%s|%s||' "$http_port" "$https_port")
    fi
}

configure_monitoring_service() {
    echo -e "\n${YELLOW}Monitoring Configuration:${NC}"

    read -p "Prometheus port [9090]: " prometheus_port
    prometheus_port=${prometheus_port:-9090}

    read -p "Grafana port [3001]: " grafana_port
    grafana_port=${grafana_port:-3001}

    read -p "Grafana admin username [admin]: " grafana_user
    grafana_user=${grafana_user:-admin}

    read -s -p "Grafana admin password: " grafana_password
    echo ""

    SERVICE_CONFIGS["monitoring"]=$(printf '%s|%s|%s|%s' "$prometheus_port" "$grafana_port" "$grafana_user" "$grafana_password")
}

generate_swarm_config() {
    print_step "Generating Docker Swarm configuration..."

    # Generate main compose file for swarm
    cat > "$CONFIG_DIR/docker-compose.swarm.yml" << 'EOF'
version: '3.8'

services:
  cms-api:
    image: exiled-cms-api:latest
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - DATABASE_PROVIDER=${DATABASE_PROVIDER}
      - ConnectionStrings__DefaultConnection=${DB_CONNECTION_STRING}
      - ConnectionStrings__Redis=${REDIS_CONNECTION_STRING}
    networks:
      - exiled-distributed
    deploy:
      replicas: ${CMS_API_REPLICAS}
      placement:
        constraints:
          - node.labels.type == api
      resources:
        limits:
          memory: ${CMS_API_MEMORY}
        reservations:
          memory: 256M
    ports:
      - "5006:80"

networks:
  exiled-distributed:
    external: true
    attachable: true
EOF

    print_success "Swarm configuration generated"
}

generate_deployment_scripts() {
    print_step "Generating deployment scripts..."

    # Manager initialization script
    cat > "$CONFIG_DIR/init-manager.sh" << 'EOF'
#!/bin/bash
# Initialize Swarm Manager
docker swarm init --advertise-addr $1
docker network create --driver overlay --attachable exiled-distributed
EOF

    # Worker join script template
    cat > "$CONFIG_DIR/join-worker.sh" << 'EOF'
#!/bin/bash
# Join as worker node
docker swarm join --token $1 $2:2377
EOF

    # Service deployment script
    cat > "$CONFIG_DIR/deploy-services.sh" << 'EOF'
#!/bin/bash
# Deploy all services
source .env
docker stack deploy -c docker-compose.swarm.yml exiledproject-cms
EOF

    chmod +x "$CONFIG_DIR"/*.sh
    print_success "Deployment scripts generated"
}

show_deployment_plan() {
    echo -e "\n${CYAN}${BOLD}=== DEPLOYMENT PLAN ===${NC}"
    echo ""

    echo -e "${YELLOW}Machines configured:${NC}"
    while read -r line; do
        if echo "$line" | grep -q '"ip"'; then
            local ip=$(echo "$line" | grep -o '"ip": *"[^"]*"' | cut -d'"' -f4)
            local name=$(echo "$line" | grep -o '"name": *"[^"]*"' | cut -d'"' -f4)
            echo -e "  ${GREEN}$name${NC}: $ip"
        fi
    done < "$NODES_CONFIG"

    echo ""
    echo -e "${YELLOW}Services to deploy:${NC}"
    for service in "${!SERVICE_PLACEMENT[@]}"; do
        echo -e "  ${GREEN}$service${NC}: ${SERVICE_PLACEMENT[$service]}"
    done

    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "  1. Initialize Swarm manager on primary node"
    echo -e "  2. Join worker nodes to the swarm"
    echo -e "  3. Label nodes according to their roles"
    echo -e "  4. Deploy services stack"
    echo -e "  5. Configure service discovery and networking"

    echo ""
    if ask_yes_no "Proceed with deployment?" "y"; then
        return 0
    else
        print_warning "Deployment cancelled"
        exit 0
    fi
}

deploy_to_swarm() {
    print_step "Deploying to Docker Swarm..."

    echo -e "${YELLOW}Manual steps required:${NC}"
    echo ""
    echo "1. On your manager node, run:"
    echo -e "   ${CYAN}cd $CONFIG_DIR && ./init-manager.sh <MANAGER_IP>${NC}"
    echo ""
    echo "2. On each worker node, run the join command that will be displayed"
    echo ""
    echo "3. Label your nodes:"
    echo -e "   ${CYAN}docker node update --label-add type=api <node-name>${NC}"
    echo ""
    echo "4. Deploy services:"
    echo -e "   ${CYAN}cd $CONFIG_DIR && ./deploy-services.sh${NC}"

    print_success "Deployment instructions generated"
}

show_completion_info() {
    echo -e "\n${GREEN}${BOLD}🎉 Distributed deployment configuration completed!${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}=== CONFIGURATION FILES ===${NC}"
    echo -e "${GREEN}Machines config:${NC}      $NODES_CONFIG"
    echo -e "${GREEN}Services config:${NC}      $SERVICES_CONFIG"
    echo -e "${GREEN}Swarm compose:${NC}        $CONFIG_DIR/docker-compose.swarm.yml"
    echo -e "${GREEN}Deployment scripts:${NC}   $CONFIG_DIR/*.sh"
    echo ""
    echo -e "${CYAN}${BOLD}=== MANAGEMENT COMMANDS ===${NC}"
    echo -e "${GREEN}Check swarm status:${NC}   docker node ls"
    echo -e "${GREEN}View services:${NC}        docker service ls"
    echo -e "${GREEN}Scale service:${NC}        docker service scale exiledproject-cms_api=3"
    echo -e "${GREEN}View logs:${NC}            docker service logs -f exiledproject-cms_api"
    echo ""
    echo -e "${YELLOW}${BOLD}Important:${NC}"
    echo -e "${YELLOW}• Ensure Docker Swarm is properly initialized${NC}"
    echo -e "${YELLOW}• Configure firewall for inter-node communication${NC}"
    echo -e "${YELLOW}• Set up shared storage for persistent data${NC}"
    echo -e "${YELLOW}• Configure SSL certificates for production${NC}"
    echo ""
}

main() {
    print_banner

    setup_directories
    discover_machines
    configure_services
    generate_swarm_config
    generate_deployment_scripts
    show_deployment_plan
    deploy_to_swarm
    show_completion_info
}

# Error handling
trap 'echo -e "\n${RED}Installation interrupted${NC}"; exit 1' INT TERM

# Run main function
main "$@"