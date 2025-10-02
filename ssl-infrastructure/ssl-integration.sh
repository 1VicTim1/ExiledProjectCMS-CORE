#!/bin/bash

# SSL Integration for ExiledProjectCMS Interactive Installer
# Adds SSL configuration options to the main installer

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() { echo -e "${BLUE}[SSL]${NC} $1"; }
print_success() { echo -e "${GREEN}[SSL]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[SSL]${NC} $1"; }

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

configure_ssl() {
    echo -e "\n${CYAN}=== SSL CONFIGURATION ===${NC}"
    echo -e "${CYAN}Configure SSL for secure inter-service communication${NC}"
    echo ""

    if ask_yes_no "Enable SSL for inter-service communication?" "y"; then
        SSL_ENABLED="true"
        echo -e "${GREEN}✓ SSL will be enabled${NC}"

        # SSL mode selection
        echo ""
        echo "SSL Certificate Mode:"
        echo "1) Generate new certificates (recommended for new installations)"
        echo "2) Use existing certificates"
        echo "3) Generate and use Let's Encrypt certificates"

        while true; do
            read -p "Select SSL mode (1-3) [1]: " ssl_mode
            ssl_mode=${ssl_mode:-1}

            case $ssl_mode in
                1)
                    SSL_MODE="generate"
                    configure_generated_ssl
                    break
                    ;;
                2)
                    SSL_MODE="existing"
                    configure_existing_ssl
                    break
                    ;;
                3)
                    SSL_MODE="letsencrypt"
                    configure_letsencrypt_ssl
                    break
                    ;;
                *)
                    echo "Invalid choice. Please select 1-3."
                    ;;
            esac
        done

        # SSL security level
        configure_ssl_security_level

        # Update component selection for SSL
        update_components_for_ssl

    else
        SSL_ENABLED="false"
        echo -e "${YELLOW}⚠ SSL disabled - not recommended for production${NC}"
    fi
}

configure_generated_ssl() {
    print_step "Configuring SSL certificate generation..."

    # Organization details for certificates
    read -p "Organization name [ExiledProjectCMS]: " SSL_ORG_NAME
    SSL_ORG_NAME=${SSL_ORG_NAME:-ExiledProjectCMS}

    read -p "Organization unit [IT Department]: " SSL_ORG_UNIT
    SSL_ORG_UNIT=${SSL_ORG_UNIT:-IT Department}

    read -p "Country code [US]: " SSL_COUNTRY
    SSL_COUNTRY=${SSL_COUNTRY:-US}

    read -p "State/Province [State]: " SSL_STATE
    SSL_STATE=${SSL_STATE:-State}

    read -p "City [City]: " SSL_CITY
    SSL_CITY=${SSL_CITY:-City}

    # Certificate validity
    read -p "Certificate validity in days [365]: " SSL_VALIDITY_DAYS
    SSL_VALIDITY_DAYS=${SSL_VALIDITY_DAYS:-365}

    print_success "SSL generation configured"
}

configure_existing_ssl() {
    print_step "Configuring existing SSL certificates..."

    read -p "Path to CA certificate: " SSL_CA_CERT_PATH
    read -p "Path to CA private key: " SSL_CA_KEY_PATH

    # Verify certificate files exist
    if [ ! -f "$SSL_CA_CERT_PATH" ]; then
        print_warning "CA certificate file not found: $SSL_CA_CERT_PATH"
    fi

    if [ ! -f "$SSL_CA_KEY_PATH" ]; then
        print_warning "CA private key file not found: $SSL_CA_KEY_PATH"
    fi

    read -p "Path to service certificates directory: " SSL_CERTS_DIR

    print_success "Existing SSL certificates configured"
}

configure_letsencrypt_ssl() {
    print_step "Configuring Let's Encrypt SSL..."

    read -p "Email address for Let's Encrypt: " LETSENCRYPT_EMAIL

    if [ -z "$LETSENCRYPT_EMAIL" ]; then
        print_warning "Email is required for Let's Encrypt"
        return 1
    fi

    read -p "Domain for public certificate: " LETSENCRYPT_DOMAIN
    if [ -z "$LETSENCRYPT_DOMAIN" ]; then
        LETSENCRYPT_DOMAIN="$DOMAIN_NAME"
    fi

    if ask_yes_no "Use staging environment for testing?" "n"; then
        LETSENCRYPT_STAGING="true"
    else
        LETSENCRYPT_STAGING="false"
    fi

    print_success "Let's Encrypt SSL configured"
}

configure_ssl_security_level() {
    echo ""
    echo "SSL Security Level:"
    echo "1) Standard (TLS 1.2+, recommended for most environments)"
    echo "2) High Security (TLS 1.3 only, strict ciphers)"
    echo "3) Custom (specify your own settings)"

    while true; do
        read -p "Select security level (1-3) [1]: " ssl_security
        ssl_security=${ssl_security:-1}

        case $ssl_security in
            1)
                SSL_MIN_VERSION="TLSv1.2"
                SSL_CIPHERS="ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256"
                SSL_SECURITY_LEVEL="standard"
                break
                ;;
            2)
                SSL_MIN_VERSION="TLSv1.3"
                SSL_CIPHERS="TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256"
                SSL_SECURITY_LEVEL="high"
                break
                ;;
            3)
                SSL_SECURITY_LEVEL="custom"
                configure_custom_ssl_security
                break
                ;;
            *)
                echo "Invalid choice. Please select 1-3."
                ;;
        esac
    done

    echo -e "${GREEN}✓ SSL security level: $SSL_SECURITY_LEVEL${NC}"
}

configure_custom_ssl_security() {
    read -p "Minimum TLS version [TLSv1.2]: " SSL_MIN_VERSION
    SSL_MIN_VERSION=${SSL_MIN_VERSION:-TLSv1.2}

    read -p "SSL cipher suites: " SSL_CIPHERS

    if ask_yes_no "Require client certificates for internal communication?" "y"; then
        SSL_REQUIRE_CLIENT_CERTS="true"
    else
        SSL_REQUIRE_CLIENT_CERTS="false"
    fi

    if ask_yes_no "Enable OCSP stapling?" "y"; then
        SSL_OCSP_STAPLING="true"
    else
        SSL_OCSP_STAPLING="false"
    fi
}

update_components_for_ssl() {
    print_step "Updating component selection for SSL..."

    # Replace regular templates with SSL versions
    local updated_components=()

    for component in "${SELECTED_COMPONENTS[@]}"; do
        case $component in
            "database-mysql"|"database-postgres"|"database-sqlserver")
                updated_components+=("${component}-ssl")
                ;;
            "cache-redis")
                updated_components+=("cache-redis-ssl")
                ;;
            "services-go"|"services-skins"|"services-email")
                updated_components+=("${component}-ssl")
                ;;
            "frontend")
                updated_components+=("frontend-ssl")
                ;;
            "loadbalancer")
                updated_components+=("loadbalancer-ssl")
                ;;
            *)
                updated_components+=("$component")
                ;;
        esac
    done

    # Use base-ssl template instead of base
    updated_components=("base-ssl" "${updated_components[@]}")

    SELECTED_COMPONENTS=("${updated_components[@]}")

    print_success "Components updated for SSL support"
}

generate_ssl_certificates() {
    if [ "$SSL_ENABLED" = "true" ] && [ "$SSL_MODE" = "generate" ]; then
        print_step "Generating SSL certificates..."

        # Run the certificate generation script
        cd ssl-infrastructure
        chmod +x generate-certificates.sh

        # Set environment variables for certificate generation
        export SSL_ORG_NAME SSL_ORG_UNIT SSL_COUNTRY SSL_STATE SSL_CITY SSL_VALIDITY_DAYS

        ./generate-certificates.sh

        print_success "SSL certificates generated"
        cd ..
    fi
}

configure_ssl_environment_variables() {
    if [ "$SSL_ENABLED" = "true" ]; then
        print_step "Configuring SSL environment variables..."

        # SSL-specific environment variables
        cat >> .env << EOF

# ===========================================
# SSL CONFIGURATION
# ===========================================
SSL_ENABLED=$SSL_ENABLED
SSL_MODE=$SSL_MODE
SSL_SECURITY_LEVEL=$SSL_SECURITY_LEVEL
SSL_MIN_VERSION=$SSL_MIN_VERSION
SSL_CIPHERS=$SSL_CIPHERS
SSL_REQUIRE_CLIENT_CERTS=${SSL_REQUIRE_CLIENT_CERTS:-true}
SSL_OCSP_STAPLING=${SSL_OCSP_STAPLING:-true}

# SSL Ports
API_SSL_PORT=${API_SSL_PORT:-5443}
API_INTERNAL_PORT=${API_INTERNAL_PORT:-5444}
GO_API_SSL_PORT=${GO_API_SSL_PORT:-8443}
GO_API_INTERNAL_PORT=${GO_API_INTERNAL_PORT:-8444}
REDIS_SSL_PORT=${REDIS_SSL_PORT:-6380}
NGINX_INTERNAL_PORT=${NGINX_INTERNAL_PORT:-8443}
NGINX_HEALTH_PORT=${NGINX_HEALTH_PORT:-8080}

# SSL Certificate Paths
SSL_CERTS_DIR=./ssl-certificates
SSL_CA_CERT_PATH=./ssl-certificates/ca/ca.crt
SSL_CA_KEY_PATH=./ssl-certificates/ca/ca.key

# SSL Connection Strings
DB_CONNECTION_STRING_SSL=${DB_CONNECTION_STRING_SSL}
GO_DB_CONNECTION_STRING_SSL=${GO_DB_CONNECTION_STRING_SSL}
REDIS_CONNECTION_STRING_SSL=${REDIS_CONNECTION_STRING_SSL}

# Let's Encrypt (if applicable)
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
LETSENCRYPT_DOMAIN=${LETSENCRYPT_DOMAIN}
LETSENCRYPT_STAGING=${LETSENCRYPT_STAGING:-false}
EOF

        print_success "SSL environment variables configured"
    fi
}

update_connection_strings_for_ssl() {
    if [ "$SSL_ENABLED" = "true" ]; then
        print_step "Updating connection strings for SSL..."

        # Update database connection strings
        case $DATABASE_PROVIDER in
            MySQL)
                if [ -z "$DB_CONNECTION_STRING" ]; then
                    DB_CONNECTION_STRING_SSL="Server=mysql;Database=$DB_NAME;Uid=$DB_USER;Pwd=$DB_PASSWORD;SslMode=Required;SslCert=/app/ssl/clients/internal-client-client.crt;SslKey=/app/ssl/clients/internal-client-client.key;SslCa=/app/ssl/ca.crt;"
                    GO_DB_CONNECTION_STRING_SSL="$DB_USER:$DB_PASSWORD@tcp(mysql:3306)/$DB_NAME?tls=custom&charset=utf8mb4&parseTime=True&loc=Local"
                else
                    DB_CONNECTION_STRING_SSL="${DB_CONNECTION_STRING%;};SslMode=Required;SslCert=/app/ssl/clients/internal-client-client.crt;SslKey=/app/ssl/clients/internal-client-client.key;SslCa=/app/ssl/ca.crt;"
                fi
                ;;
            PostgreSQL)
                if [ -z "$DB_CONNECTION_STRING" ]; then
                    DB_CONNECTION_STRING_SSL="Host=postgres;Database=$DB_NAME;Username=$DB_USER;Password=$DB_PASSWORD;SslMode=Require;ClientCertificate=/app/ssl/clients/internal-client-client.crt;ClientCertificateKey=/app/ssl/clients/internal-client-client.key;RootCertificate=/app/ssl/ca.crt;"
                    GO_DB_CONNECTION_STRING_SSL="postgres://$DB_USER:$DB_PASSWORD@postgres:5432/$DB_NAME?sslmode=require&sslcert=/app/ssl/clients/internal-client-client.crt&sslkey=/app/ssl/clients/internal-client-client.key&sslrootcert=/app/ssl/ca.crt"
                else
                    DB_CONNECTION_STRING_SSL="${DB_CONNECTION_STRING%;};SslMode=Require;ClientCertificate=/app/ssl/clients/internal-client-client.crt;ClientCertificateKey=/app/ssl/clients/internal-client-client.key;RootCertificate=/app/ssl/ca.crt;"
                fi
                ;;
            SqlServer)
                if [ -z "$DB_CONNECTION_STRING" ]; then
                    DB_CONNECTION_STRING_SSL="Server=sqlserver,1433;Database=$DB_NAME;User Id=sa;Password=$DB_SA_PASSWORD;Encrypt=true;TrustServerCertificate=false;Certificate=/app/ssl/clients/internal-client-client.crt;"
                    GO_DB_CONNECTION_STRING_SSL="sqlserver://sa:$DB_SA_PASSWORD@sqlserver:1433?database=$DB_NAME&encrypt=true&TrustServerCertificate=false"
                else
                    DB_CONNECTION_STRING_SSL="${DB_CONNECTION_STRING%;};Encrypt=true;TrustServerCertificate=false;Certificate=/app/ssl/clients/internal-client-client.crt;"
                fi
                ;;
        esac

        # Update Redis connection string for SSL
        if [ "$CACHE_PROVIDER" = "Redis" ]; then
            if [ -z "$REDIS_CONNECTION_STRING" ]; then
                REDIS_CONNECTION_STRING_SSL="rediss://redis:6380,password=$REDIS_PASSWORD,ssl=true,sslHost=redis.exiled.local"
            else
                # Convert existing Redis connection to SSL
                REDIS_CONNECTION_STRING_SSL=$(echo "$REDIS_CONNECTION_STRING" | sed 's/redis:/rediss:/' | sed 's/:6379/:6380/' | sed 's/$/,ssl=true,sslHost=redis.exiled.local/')
            fi
        fi

        print_success "Connection strings updated for SSL"
    fi
}

create_ssl_docker_compose() {
    if [ "$SSL_ENABLED" = "true" ]; then
        print_step "Creating SSL-enabled Docker Compose configuration..."

        # The main installer will use the updated SELECTED_COMPONENTS
        # which now include SSL versions of templates

        print_success "SSL Docker Compose configuration prepared"
    fi
}

show_ssl_summary() {
    if [ "$SSL_ENABLED" = "true" ]; then
        echo ""
        echo -e "${CYAN}=== SSL CONFIGURATION SUMMARY ===${NC}"
        echo -e "${GREEN}SSL Mode:${NC}           $SSL_MODE"
        echo -e "${GREEN}Security Level:${NC}     $SSL_SECURITY_LEVEL"
        echo -e "${GREEN}TLS Version:${NC}        $SSL_MIN_VERSION+"
        echo -e "${GREEN}Client Certs:${NC}       ${SSL_REQUIRE_CLIENT_CERTS:-true}"

        if [ "$SSL_MODE" = "generate" ]; then
            echo -e "${GREEN}Certificates:${NC}       Generated automatically"
            echo -e "${GREEN}CA Validity:${NC}        10 years"
            echo -e "${GREEN}Service Validity:${NC}   $SSL_VALIDITY_DAYS days"
        elif [ "$SSL_MODE" = "existing" ]; then
            echo -e "${GREEN}Certificates:${NC}       Using existing certificates"
        elif [ "$SSL_MODE" = "letsencrypt" ]; then
            echo -e "${GREEN}Certificates:${NC}       Let's Encrypt"
            echo -e "${GREEN}Domain:${NC}             $LETSENCRYPT_DOMAIN"
            echo -e "${GREEN}Staging:${NC}            $LETSENCRYPT_STAGING"
        fi

        echo ""
        echo -e "${YELLOW}SSL Security Features:${NC}"
        echo -e "  ✓ Inter-service encryption (TLS)"
        echo -e "  ✓ Mutual authentication (mTLS)"
        echo -e "  ✓ Certificate-based access control"
        echo -e "  ✓ Perfect Forward Secrecy (PFS)"
        echo -e "  ✓ OCSP stapling (if enabled)"
        echo ""
        echo -e "${YELLOW}Important SSL Notes:${NC}"
        echo -e "  • Keep your CA private key secure"
        echo -e "  • Set up certificate renewal automation"
        echo -e "  • Monitor certificate expiration dates"
        echo -e "  • Configure firewall for SSL ports"
        echo ""
    fi
}

# Export functions for use in main installer
export -f configure_ssl
export -f generate_ssl_certificates
export -f configure_ssl_environment_variables
export -f update_connection_strings_for_ssl
export -f create_ssl_docker_compose
export -f show_ssl_summary