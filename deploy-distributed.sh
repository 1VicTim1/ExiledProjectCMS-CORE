#!/bin/bash

# ExiledProjectCMS Distributed Deployment Manager
# This script helps deploy ExiledProjectCMS across multiple machines using Docker Swarm

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SWARM_NETWORK="exiled-distributed"
STACK_NAME="exiledproject-cms"

print_banner() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}${CYAN}      ExiledProjectCMS Distributed Deploy      ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${YELLOW}         Docker Swarm Management              ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════╝${NC}"
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

show_help() {
    echo "ExiledProjectCMS Distributed Deployment Manager"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  init-swarm           Initialize Docker Swarm cluster"
    echo "  join-swarm TOKEN     Join existing swarm with token"
    echo "  deploy               Deploy ExiledProjectCMS stack"
    echo "  scale                Scale services"
    echo "  update               Update services"
    echo "  remove               Remove stack"
    echo "  status               Show cluster status"
    echo "  logs                 Show service logs"
    echo ""
    echo "Options:"
    echo "  --manager-ip IP      Manager node IP address"
    echo "  --database-node IP   Database node IP"
    echo "  --redis-node IP      Redis node IP"
    echo "  --nfs-server IP      NFS server IP"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 init-swarm --manager-ip 192.168.1.10"
    echo "  $0 join-swarm SWMTKN-1-... --manager-ip 192.168.1.10"
    echo "  $0 deploy --database-node 192.168.1.11 --redis-node 192.168.1.12"
    echo "  $0 scale cms-api=3 go-api=5"
}

init_swarm() {
    print_step "Initializing Docker Swarm..."

    if docker info | grep -q "Swarm: active"; then
        print_success "Swarm is already initialized"
        return
    fi

    local manager_ip=$1
    if [ -z "$manager_ip" ]; then
        manager_ip=$(hostname -I | awk '{print $1}')
    fi

    docker swarm init --advertise-addr $manager_ip

    # Create overlay network
    docker network create --driver overlay --attachable $SWARM_NETWORK || true

    print_success "Swarm initialized with manager IP: $manager_ip"

    # Show join tokens
    echo ""
    echo -e "${CYAN}=== JOIN TOKENS ===${NC}"
    echo -e "${YELLOW}Worker token:${NC}"
    docker swarm join-token worker -q
    echo -e "${YELLOW}Manager token:${NC}"
    docker swarm join-token manager -q
}

join_swarm() {
    local token=$1
    local manager_ip=$2

    if [ -z "$token" ] || [ -z "$manager_ip" ]; then
        print_error "Token and manager IP are required"
        exit 1
    fi

    print_step "Joining Docker Swarm..."

    docker swarm join --token $token $manager_ip:2377

    print_success "Successfully joined swarm"
}

label_nodes() {
    print_step "Labeling nodes for service placement..."

    # Get all nodes
    local nodes=($(docker node ls --format "{{.Hostname}}"))

    echo "Available nodes:"
    for i in "${!nodes[@]}"; do
        echo "$((i+1)). ${nodes[$i]}"
    done

    # Interactive node labeling
    echo ""
    echo "Assign roles to nodes:"
    echo "1) API nodes (cms-api service)"
    echo "2) Compute nodes (go-api service)"
    echo "3) Frontend nodes (admin-panel, webapp)"
    echo "4) Load balancer nodes (nginx)"
    echo "5) Database nodes"
    echo "6) Cache nodes (Redis)"

    for node in "${nodes[@]}"; do
        echo ""
        echo -e "${CYAN}Node: $node${NC}"
        read -p "Select type (1-6) or enter for skip: " node_type

        case $node_type in
            1) docker node update --label-add type=api $node ;;
            2) docker node update --label-add type=compute $node ;;
            3) docker node update --label-add type=frontend $node ;;
            4) docker node update --label-add type=loadbalancer $node ;;
            5) docker node update --label-add type=database $node ;;
            6) docker node update --label-add type=cache $node ;;
            *) echo "Skipping $node" ;;
        esac
    done

    print_success "Node labeling completed"
}

create_configs() {
    print_step "Creating Docker configs and secrets..."

    # Create .env config
    if [ -f .env ]; then
        docker config create exiled-env-$(date +%s) .env || true
    fi

    # Create nginx config
    if [ -f nginx/distributed.conf ]; then
        docker config create exiled-nginx-$(date +%s) nginx/distributed.conf || true
    fi

    print_success "Configs created"
}

deploy_infrastructure() {
    local database_node=$1
    local redis_node=$2
    local nfs_server=$3

    print_step "Deploying infrastructure services..."

    # Database service (if specified)
    if [ ! -z "$database_node" ]; then
        print_step "Deploying database on node: $database_node"

        cat > infrastructure-stack.yml << EOF
version: '3.8'
services:
  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=\${DB_NAME:-ExiledProjectCMS}
      - POSTGRES_USER=\${DB_USER:-exiled}
      - POSTGRES_PASSWORD=\${DB_PASSWORD:-ExiledPass123!}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - $SWARM_NETWORK
    deploy:
      placement:
        constraints:
          - node.hostname == $database_node
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

volumes:
  postgres_data:
    external: true

networks:
  $SWARM_NETWORK:
    external: true
EOF

        docker stack deploy -c infrastructure-stack.yml exiled-infrastructure
        print_success "Database deployed on $database_node"
    fi

    # Redis service (if specified)
    if [ ! -z "$redis_node" ]; then
        print_step "Deploying Redis on node: $redis_node"

        cat > redis-stack.yml << EOF
version: '3.8'
services:
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes --requirepass \${REDIS_PASSWORD:-ExiledRedis123!}
    volumes:
      - redis_data:/data
    networks:
      - $SWARM_NETWORK
    deploy:
      placement:
        constraints:
          - node.hostname == $redis_node
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

volumes:
  redis_data:
    external: true

networks:
  $SWARM_NETWORK:
    external: true
EOF

        docker stack deploy -c redis-stack.yml exiled-redis
        print_success "Redis deployed on $redis_node"
    fi
}

deploy_application() {
    print_step "Deploying ExiledProjectCMS application stack..."

    # Load environment variables
    if [ -f .env ]; then
        set -a
        source .env
        set +a
    fi

    # Deploy main application stack
    docker stack deploy -c docker-compose.distributed.yml $STACK_NAME

    print_success "Application stack deployed"
}

scale_services() {
    local services="$@"

    print_step "Scaling services..."

    for service in $services; do
        if [[ $service == *"="* ]]; then
            local service_name=$(echo $service | cut -d'=' -f1)
            local replicas=$(echo $service | cut -d'=' -f2)

            docker service scale ${STACK_NAME}_${service_name}=$replicas
            print_success "Scaled $service_name to $replicas replicas"
        fi
    done
}

update_services() {
    print_step "Updating services..."

    # Build new images
    docker-compose -f docker-compose.distributed.yml build

    # Update services
    docker stack deploy -c docker-compose.distributed.yml $STACK_NAME

    print_success "Services updated"
}

show_status() {
    print_step "Cluster Status:"
    echo ""

    echo -e "${CYAN}=== NODES ===${NC}"
    docker node ls

    echo ""
    echo -e "${CYAN}=== SERVICES ===${NC}"
    docker service ls

    echo ""
    echo -e "${CYAN}=== STACK SERVICES ===${NC}"
    docker stack services $STACK_NAME 2>/dev/null || echo "Stack not deployed"

    echo ""
    echo -e "${CYAN}=== NETWORK ===${NC}"
    docker network ls | grep $SWARM_NETWORK || echo "Network not found"
}

show_logs() {
    local service=$1

    if [ -z "$service" ]; then
        echo "Available services:"
        docker stack services $STACK_NAME --format "table {{.Name}}"
        read -p "Enter service name: " service
    fi

    docker service logs -f ${STACK_NAME}_${service}
}

remove_stack() {
    print_step "Removing ExiledProjectCMS stack..."

    docker stack rm $STACK_NAME
    docker stack rm exiled-infrastructure 2>/dev/null || true
    docker stack rm exiled-redis 2>/dev/null || true

    print_success "Stack removed"
}

main() {
    print_banner

    case "$1" in
        init-swarm)
            shift
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --manager-ip)
                        MANAGER_IP="$2"
                        shift 2
                        ;;
                    *)
                        shift
                        ;;
                esac
            done
            init_swarm $MANAGER_IP
            label_nodes
            ;;
        join-swarm)
            shift
            TOKEN="$1"
            shift
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --manager-ip)
                        MANAGER_IP="$2"
                        shift 2
                        ;;
                    *)
                        shift
                        ;;
                esac
            done
            join_swarm $TOKEN $MANAGER_IP
            ;;
        deploy)
            shift
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --database-node)
                        DATABASE_NODE="$2"
                        shift 2
                        ;;
                    --redis-node)
                        REDIS_NODE="$2"
                        shift 2
                        ;;
                    --nfs-server)
                        NFS_SERVER="$2"
                        shift 2
                        ;;
                    *)
                        shift
                        ;;
                esac
            done
            create_configs
            deploy_infrastructure $DATABASE_NODE $REDIS_NODE $NFS_SERVER
            sleep 10
            deploy_application
            ;;
        scale)
            shift
            scale_services "$@"
            ;;
        update)
            update_services
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs $2
            ;;
        remove)
            remove_stack
            ;;
        --help|help)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"