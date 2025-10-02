#!/bin/bash

# ExiledProjectCMS Universal Installer for Linux
# This script installs and configures ExiledProjectCMS with Docker support

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/exiledproject-cms"
SERVICE_USER="exiled"
CONFIG_DIR="/etc/exiledproject-cms"
LOG_FILE="/var/log/exiledproject-cms-install.log"

# Functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

print_banner() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}${CYAN}          ExiledProjectCMS Installer           ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${YELLOW}     Advanced CMS with Docker Support         ${NC}${PURPLE}║${NC}"
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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_os() {
    print_step "Detecting operating system..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID

        case $ID in
            ubuntu|debian)
                PKG_MANAGER="apt"
                PKG_UPDATE="apt update"
                PKG_INSTALL="apt install -y"
                ;;
            centos|rhel|rocky|almalinux)
                PKG_MANAGER="yum"
                PKG_UPDATE="yum update -y"
                PKG_INSTALL="yum install -y"
                ;;
            fedora)
                PKG_MANAGER="dnf"
                PKG_UPDATE="dnf update -y"
                PKG_INSTALL="dnf install -y"
                ;;
            arch)
                PKG_MANAGER="pacman"
                PKG_UPDATE="pacman -Sy"
                PKG_INSTALL="pacman -S --noconfirm"
                ;;
            *)
                print_warning "Unsupported OS: $ID"
                print_warning "Installation will continue with generic Linux support"
                PKG_MANAGER="unknown"
                ;;
        esac

        print_success "Detected: $OS $VER"
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
}

install_dependencies() {
    print_step "Installing system dependencies..."

    case $PKG_MANAGER in
        apt)
            $PKG_UPDATE
            $PKG_INSTALL curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release
            ;;
        yum|dnf)
            $PKG_UPDATE
            $PKG_INSTALL curl wget git unzip yum-utils device-mapper-persistent-data lvm2
            ;;
        pacman)
            $PKG_UPDATE
            $PKG_INSTALL curl wget git unzip base-devel
            ;;
        *)
            print_warning "Please manually install: curl, wget, git, unzip"
            ;;
    esac

    print_success "System dependencies installed"
}

install_docker() {
    print_step "Installing Docker..."

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_success "Docker is already installed"
        docker --version
        return
    fi

    case $PKG_MANAGER in
        apt)
            # Add Docker's official GPG key
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

            # Add Docker repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

            # Install Docker
            apt update
            $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        yum|dnf)
            # Add Docker repository
            $PKG_INSTALL yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

            # Install Docker
            $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        pacman)
            $PKG_INSTALL docker docker-compose
            ;;
        *)
            print_error "Please manually install Docker for your distribution"
            exit 1
            ;;
    esac

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    print_success "Docker installed successfully"
    docker --version
}

install_docker_compose() {
    print_step "Installing Docker Compose..."

    # Check if docker-compose is already available
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose is already installed"
        docker-compose --version
        return
    fi

    # Install Docker Compose
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    print_success "Docker Compose installed successfully"
    docker-compose --version
}

create_system_user() {
    print_step "Creating system user..."

    if id "$SERVICE_USER" &>/dev/null; then
        print_success "User $SERVICE_USER already exists"
    else
        useradd -r -s /bin/bash -d "$INSTALL_DIR" "$SERVICE_USER"
        usermod -aG docker "$SERVICE_USER"
        print_success "User $SERVICE_USER created"
    fi
}

setup_directories() {
    print_step "Setting up directories..."

    # Create directories
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p /var/log/exiledproject-cms
    mkdir -p /var/lib/exiledproject-cms/{plugins,uploads,backups}

    # Set permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$CONFIG_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" /var/log/exiledproject-cms
    chown -R "$SERVICE_USER:$SERVICE_USER" /var/lib/exiledproject-cms

    print_success "Directories created and configured"
}

configure_environment() {
    print_step "Configuring environment..."

    # Copy environment template
    cp .env.example "$CONFIG_DIR/.env"
    chown "$SERVICE_USER:$SERVICE_USER" "$CONFIG_DIR/.env"
    chmod 600 "$CONFIG_DIR/.env"

    # Interactive configuration
    echo -e "${CYAN}Environment Configuration${NC}"
    echo "Configure your ExiledProjectCMS installation:"
    echo ""

    # Database selection
    echo "Select database provider:"
    echo "1) SQL Server (recommended for Windows environments)"
    echo "2) MySQL (recommended for general use)"
    echo "3) PostgreSQL (recommended for high-performance)"
    read -p "Enter choice (1-3) [2]: " db_choice
    db_choice=${db_choice:-2}

    case $db_choice in
        1) DATABASE_PROVIDER="SqlServer" ;;
        2) DATABASE_PROVIDER="MySQL" ;;
        3) DATABASE_PROVIDER="PostgreSQL" ;;
        *) DATABASE_PROVIDER="MySQL" ;;
    esac

    # Cache selection
    echo "Select cache provider:"
    echo "1) Memory (development/single instance)"
    echo "2) Redis (recommended for production)"
    read -p "Enter choice (1-2) [2]: " cache_choice
    cache_choice=${cache_choice:-2}

    case $cache_choice in
        1) CACHE_PROVIDER="Memory" ;;
        2) CACHE_PROVIDER="Redis" ;;
        *) CACHE_PROVIDER="Redis" ;;
    esac

    # Admin user configuration
    read -p "Admin username [admin]: " admin_user
    admin_user=${admin_user:-admin}

    read -p "Admin email [admin@example.com]: " admin_email
    admin_email=${admin_email:-admin@example.com}

    while true; do
        read -s -p "Admin password (min 8 characters): " admin_pass
        echo
        if [[ ${#admin_pass} -ge 8 ]]; then
            break
        else
            print_error "Password must be at least 8 characters long"
        fi
    done

    # Domain configuration
    read -p "Domain name (for SSL) [localhost]: " domain_name
    domain_name=${domain_name:-localhost}

    # Update .env file
    sed -i "s/DATABASE_PROVIDER=.*/DATABASE_PROVIDER=$DATABASE_PROVIDER/" "$CONFIG_DIR/.env"
    sed -i "s/CACHE_PROVIDER=.*/CACHE_PROVIDER=$CACHE_PROVIDER/" "$CONFIG_DIR/.env"
    sed -i "s/ADMIN_USERNAME=.*/ADMIN_USERNAME=$admin_user/" "$CONFIG_DIR/.env"
    sed -i "s/ADMIN_EMAIL=.*/ADMIN_EMAIL=$admin_email/" "$CONFIG_DIR/.env"
    sed -i "s/ADMIN_PASSWORD=.*/ADMIN_PASSWORD=$admin_pass/" "$CONFIG_DIR/.env"

    print_success "Environment configured"
}

deploy_application() {
    print_step "Deploying ExiledProjectCMS..."

    # Copy files to installation directory
    cp -r . "$INSTALL_DIR/"

    # Create symlink to config
    ln -sf "$CONFIG_DIR/.env" "$INSTALL_DIR/.env"

    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

    print_success "Application deployed to $INSTALL_DIR"
}

start_services() {
    print_step "Starting services..."

    cd "$INSTALL_DIR"

    # Load environment variables
    source "$CONFIG_DIR/.env"

    # Generate connection strings based on database provider
    case $DATABASE_PROVIDER in
        SqlServer)
            export DB_CONNECTION_STRING="Server=sqlserver,1433;Database=$DB_NAME;User Id=sa;Password=$DB_SA_PASSWORD;TrustServerCertificate=true;"
            export GO_DB_CONNECTION_STRING="sqlserver://sa:$DB_SA_PASSWORD@sqlserver:1433?database=$DB_NAME"
            COMPOSE_PROFILES="sqlserver"
            ;;
        MySQL)
            export DB_CONNECTION_STRING="Server=mysql;Database=$DB_NAME;Uid=$DB_USER;Pwd=$DB_PASSWORD;"
            export GO_DB_CONNECTION_STRING="$DB_USER:$DB_PASSWORD@tcp(mysql:3306)/$DB_NAME?charset=utf8mb4&parseTime=True&loc=Local"
            COMPOSE_PROFILES="mysql"
            ;;
        PostgreSQL)
            export DB_CONNECTION_STRING="Host=postgres;Database=$DB_NAME;Username=$DB_USER;Password=$DB_PASSWORD;"
            export GO_DB_CONNECTION_STRING="postgres://$DB_USER:$DB_PASSWORD@postgres:5432/$DB_NAME?sslmode=disable"
            COMPOSE_PROFILES="postgres"
            ;;
    esac

    # Start services based on configuration
    sudo -u "$SERVICE_USER" docker-compose --profile $COMPOSE_PROFILES up -d

    # Wait for services to be ready
    echo "Waiting for services to start..."
    sleep 30

    # Create admin user
    print_step "Creating admin user..."
    sudo -u "$SERVICE_USER" docker-compose exec -T cms-api dotnet ExiledProjectCMS.API.dll create-admin "$admin_user" "$admin_email" "$admin_pass" "Administrator"

    print_success "Services started successfully"
}

create_systemd_service() {
    print_step "Creating systemd service..."

    cat > /etc/systemd/system/exiledproject-cms.service << EOF
[Unit]
Description=ExiledProjectCMS Docker Services
Requires=docker.service
After=docker.service

[Service]
Type=forking
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
Environment=COMPOSE_PROJECT_NAME=exiledproject-cms
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0
Restart=on-failure
StartLimitInterval=60s
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable exiledproject-cms

    print_success "Systemd service created and enabled"
}

setup_firewall() {
    print_step "Configuring firewall..."

    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian UFW
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 3000/tcp
        ufw allow 5006/tcp
        ufw allow 8080/tcp
        print_success "UFW firewall configured"
    elif command -v firewalld &> /dev/null; then
        # CentOS/RHEL firewalld
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=3000/tcp
        firewall-cmd --permanent --add-port=5006/tcp
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --reload
        print_success "Firewalld configured"
    else
        print_warning "No supported firewall found. Please manually open ports: 80, 443, 3000, 5006, 8080"
    fi
}

print_completion_info() {
    print_success "ExiledProjectCMS installation completed successfully!"
    echo ""
    echo -e "${CYAN}=== ACCESS INFORMATION ===${NC}"
    echo -e "${GREEN}Main API:${NC}        http://$(hostname -I | awk '{print $1}'):5006"
    echo -e "${GREEN}Admin Panel:${NC}     http://$(hostname -I | awk '{print $1}'):3000"
    echo -e "${GREEN}Website:${NC}         http://$(hostname -I | awk '{print $1}'):8090"
    echo -e "${GREEN}Go API:${NC}          http://$(hostname -I | awk '{print $1}'):8080"
    echo -e "${GREEN}Load Balancer:${NC}   http://$(hostname -I | awk '{print $1}'):80"
    echo ""
    echo -e "${CYAN}=== ADMIN CREDENTIALS ===${NC}"
    echo -e "${GREEN}Username:${NC}        $admin_user"
    echo -e "${GREEN}Email:${NC}           $admin_email"
    echo -e "${GREEN}Password:${NC}        [as configured]"
    echo ""
    echo -e "${CYAN}=== MANAGEMENT COMMANDS ===${NC}"
    echo -e "${GREEN}Start services:${NC}   systemctl start exiledproject-cms"
    echo -e "${GREEN}Stop services:${NC}    systemctl stop exiledproject-cms"
    echo -e "${GREEN}View logs:${NC}        docker-compose -f $INSTALL_DIR/docker-compose.yml logs -f"
    echo -e "${GREEN}Update system:${NC}    cd $INSTALL_DIR && git pull && docker-compose build && systemctl restart exiledproject-cms"
    echo ""
    echo -e "${CYAN}=== CONFIGURATION ===${NC}"
    echo -e "${GREEN}Config file:${NC}      $CONFIG_DIR/.env"
    echo -e "${GREEN}Install dir:${NC}      $INSTALL_DIR"
    echo -e "${GREEN}Log file:${NC}         $LOG_FILE"
    echo ""
    echo -e "${YELLOW}Note: Please secure your installation by changing default passwords and configuring SSL certificates.${NC}"
}

main() {
    print_banner

    log "Starting ExiledProjectCMS installation..."

    check_root
    detect_os
    install_dependencies
    install_docker
    install_docker_compose
    create_system_user
    setup_directories
    configure_environment
    deploy_application
    start_services
    create_systemd_service
    setup_firewall

    print_completion_info

    log "Installation completed successfully"
}

# Run main function
main "$@"