#!/bin/bash

# ExiledProjectCMS SSL Certificate Generator
# Creates CA and service certificates for secure inter-service communication

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SSL_DIR="$(pwd)/ssl-certificates"
CA_DIR="$SSL_DIR/ca"
SERVICES_DIR="$SSL_DIR/services"
CONFIG_DIR="$(pwd)/ssl-config"

# Certificate validity (days)
CA_VALIDITY=3650      # 10 years for CA
SERVICE_VALIDITY=365  # 1 year for services

# Services that need certificates
SERVICES=(
    "cms-api"
    "go-api"
    "skins-service"
    "email-service"
    "admin-panel"
    "webapp"
    "nginx"
    "redis"
    "postgres"
    "mysql"
    "sqlserver"
    "prometheus"
    "grafana"
)

print_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_banner() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${YELLOW}         ExiledProjectCMS SSL Generator             ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${GREEN}    Secure Inter-Service Communication Setup       ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

setup_directories() {
    print_step "Setting up SSL directories..."

    mkdir -p "$SSL_DIR"
    mkdir -p "$CA_DIR"
    mkdir -p "$SERVICES_DIR"
    mkdir -p "$CONFIG_DIR"

    # Set secure permissions
    chmod 700 "$SSL_DIR"
    chmod 700 "$CA_DIR"
    chmod 755 "$SERVICES_DIR"

    print_success "SSL directories created"
}

create_ca_config() {
    print_step "Creating Certificate Authority configuration..."

    cat > "$CONFIG_DIR/ca.conf" << EOF
# Certificate Authority Configuration for ExiledProjectCMS

[ req ]
default_bits = 4096
prompt = no
distinguished_name = dn
x509_extensions = v3_ca

[ dn ]
C=US
ST=State
L=City
O=ExiledProjectCMS
OU=Certificate Authority
CN=ExiledProjectCMS Root CA

[ v3_ca ]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always, issuer:always
EOF

    print_success "CA configuration created"
}

generate_ca_certificate() {
    print_step "Generating Certificate Authority..."

    # Generate CA private key
    openssl genpkey -algorithm RSA -bits 4096 -out "$CA_DIR/ca.key"
    chmod 600 "$CA_DIR/ca.key"

    # Generate CA certificate
    openssl req -new -x509 -config "$CONFIG_DIR/ca.conf" \
        -key "$CA_DIR/ca.key" \
        -out "$CA_DIR/ca.crt" \
        -days $CA_VALIDITY

    chmod 644 "$CA_DIR/ca.crt"

    print_success "Certificate Authority generated"
    print_warning "Keep ca.key secure - it's the root of trust for your infrastructure!"
}

create_service_config() {
    local service="$1"

    cat > "$CONFIG_DIR/${service}.conf" << EOF
# Service Certificate Configuration for $service

[ req ]
default_bits = 2048
prompt = no
distinguished_name = dn
req_extensions = v3_req

[ dn ]
C=US
ST=State
L=City
O=ExiledProjectCMS
OU=$service Service
CN=$service.exiled.local

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $service
DNS.2 = $service.exiled.local
DNS.3 = $service.exiled-network
DNS.4 = ${service}.exiledproject-cms.local
DNS.5 = localhost
IP.1 = 127.0.0.1
EOF

    # Add service-specific DNS names
    case $service in
        "cms-api")
            cat >> "$CONFIG_DIR/${service}.conf" << EOF
DNS.6 = exiled-cms-api
DNS.7 = cms-api.exiled.local
IP.2 = 172.20.0.10
EOF
            ;;
        "go-api")
            cat >> "$CONFIG_DIR/${service}.conf" << EOF
DNS.6 = exiled-go-api
DNS.7 = go-api.exiled.local
IP.2 = 172.20.0.11
EOF
            ;;
        "nginx")
            cat >> "$CONFIG_DIR/${service}.conf" << EOF
DNS.6 = exiled-nginx
DNS.7 = loadbalancer.exiled.local
IP.2 = 172.20.0.20
EOF
            ;;
        "redis")
            cat >> "$CONFIG_DIR/${service}.conf" << EOF
DNS.6 = exiled-redis
DNS.7 = cache.exiled.local
IP.2 = 172.20.0.30
EOF
            ;;
        "postgres")
            cat >> "$CONFIG_DIR/${service}.conf" << EOF
DNS.6 = exiled-postgres
DNS.7 = database.exiled.local
IP.2 = 172.20.0.40
EOF
            ;;
    esac
}

generate_service_certificate() {
    local service="$1"
    local service_dir="$SERVICES_DIR/$service"

    print_step "Generating certificate for $service..."

    mkdir -p "$service_dir"
    chmod 755 "$service_dir"

    # Create service configuration
    create_service_config "$service"

    # Generate service private key
    openssl genpkey -algorithm RSA -bits 2048 -out "$service_dir/$service.key"
    chmod 600 "$service_dir/$service.key"

    # Generate certificate signing request
    openssl req -new -config "$CONFIG_DIR/${service}.conf" \
        -key "$service_dir/$service.key" \
        -out "$service_dir/$service.csr"

    # Sign certificate with CA
    openssl x509 -req -in "$service_dir/$service.csr" \
        -CA "$CA_DIR/ca.crt" \
        -CAkey "$CA_DIR/ca.key" \
        -CAcreateserial \
        -out "$service_dir/$service.crt" \
        -days $SERVICE_VALIDITY \
        -extensions v3_req \
        -extfile "$CONFIG_DIR/${service}.conf"

    chmod 644 "$service_dir/$service.crt"

    # Create certificate bundle (cert + CA)
    cat "$service_dir/$service.crt" "$CA_DIR/ca.crt" > "$service_dir/${service}-bundle.crt"

    # Create PEM format (key + cert + CA)
    cat "$service_dir/$service.key" "$service_dir/$service.crt" "$CA_DIR/ca.crt" > "$service_dir/${service}-full.pem"
    chmod 600 "$service_dir/${service}-full.pem"

    # Clean up CSR
    rm "$service_dir/$service.csr"

    print_success "Certificate generated for $service"
}

generate_client_certificate() {
    local client_name="$1"
    local client_dir="$SERVICES_DIR/clients/$client_name"

    print_step "Generating client certificate for $client_name..."

    mkdir -p "$client_dir"
    chmod 700 "$client_dir"

    # Create client config
    cat > "$CONFIG_DIR/${client_name}-client.conf" << EOF
[ req ]
default_bits = 2048
prompt = no
distinguished_name = dn

[ dn ]
C=US
ST=State
L=City
O=ExiledProjectCMS
OU=Client Certificate
CN=${client_name}-client
EOF

    # Generate client private key
    openssl genpkey -algorithm RSA -bits 2048 -out "$client_dir/${client_name}-client.key"
    chmod 600 "$client_dir/${client_name}-client.key"

    # Generate client certificate request
    openssl req -new -config "$CONFIG_DIR/${client_name}-client.conf" \
        -key "$client_dir/${client_name}-client.key" \
        -out "$client_dir/${client_name}-client.csr"

    # Sign client certificate
    openssl x509 -req -in "$client_dir/${client_name}-client.csr" \
        -CA "$CA_DIR/ca.crt" \
        -CAkey "$CA_DIR/ca.key" \
        -CAcreateserial \
        -out "$client_dir/${client_name}-client.crt" \
        -days $SERVICE_VALIDITY

    chmod 644 "$client_dir/${client_name}-client.crt"

    # Create client bundle
    cat "$client_dir/${client_name}-client.crt" "$CA_DIR/ca.crt" > "$client_dir/${client_name}-client-bundle.crt"

    # Clean up CSR
    rm "$client_dir/${client_name}-client.csr"

    print_success "Client certificate generated for $client_name"
}

create_docker_secrets() {
    print_step "Creating Docker secrets configuration..."

    cat > "$SSL_DIR/create-secrets.sh" << 'EOF'
#!/bin/bash

# Create Docker secrets for SSL certificates
# Run this on your Docker Swarm manager node

SSL_DIR="$(pwd)/ssl-certificates"

# Create CA certificate secret
docker secret create exiled-ca-cert $SSL_DIR/ca/ca.crt

# Create service certificate secrets
for service_dir in $SSL_DIR/services/*/; do
    service=$(basename "$service_dir")

    if [ -f "$service_dir/${service}.crt" ] && [ -f "$service_dir/${service}.key" ]; then
        echo "Creating secrets for $service..."
        docker secret create exiled-${service}-cert $service_dir/${service}.crt
        docker secret create exiled-${service}-key $service_dir/${service}.key
        docker secret create exiled-${service}-bundle $service_dir/${service}-bundle.crt
    fi
done

echo "Docker secrets created successfully!"
EOF

    chmod +x "$SSL_DIR/create-secrets.sh"

    print_success "Docker secrets script created"
}

create_kubernetes_secrets() {
    print_step "Creating Kubernetes secrets configuration..."

    cat > "$SSL_DIR/create-k8s-secrets.yaml" << 'EOF'
# Kubernetes TLS secrets for ExiledProjectCMS
apiVersion: v1
kind: Namespace
metadata:
  name: exiledproject-cms
---
apiVersion: v1
kind: Secret
metadata:
  name: exiled-ca-cert
  namespace: exiledproject-cms
type: Opaque
data:
  ca.crt: # Base64 encoded CA certificate
---
# Service certificate secrets will be generated by the script
EOF

    # Generate K8s secrets script
    cat > "$SSL_DIR/create-k8s-secrets.sh" << 'EOF'
#!/bin/bash

SSL_DIR="$(pwd)/ssl-certificates"
NAMESPACE="exiledproject-cms"

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create CA secret
kubectl create secret generic exiled-ca-cert \
    --from-file=ca.crt=$SSL_DIR/ca/ca.crt \
    --namespace=$NAMESPACE

# Create service secrets
for service_dir in $SSL_DIR/services/*/; do
    service=$(basename "$service_dir")

    if [ -f "$service_dir/${service}.crt" ] && [ -f "$service_dir/${service}.key" ]; then
        echo "Creating K8s secret for $service..."
        kubectl create secret tls exiled-${service}-tls \
            --cert=$service_dir/${service}.crt \
            --key=$service_dir/${service}.key \
            --namespace=$NAMESPACE
    fi
done

echo "Kubernetes secrets created successfully!"
EOF

    chmod +x "$SSL_DIR/create-k8s-secrets.sh"

    print_success "Kubernetes secrets script created"
}

create_validation_script() {
    print_step "Creating certificate validation script..."

    cat > "$SSL_DIR/validate-certificates.sh" << 'EOF'
#!/bin/bash

# Validate all generated certificates

SSL_DIR="$(pwd)/ssl-certificates"
CA_CERT="$SSL_DIR/ca/ca.crt"

echo "=== Certificate Validation Report ==="
echo ""

# Validate CA certificate
echo "CA Certificate:"
openssl x509 -in "$CA_CERT" -text -noout | grep -A 2 "Validity"
echo ""

# Validate service certificates
for service_dir in $SSL_DIR/services/*/; do
    service=$(basename "$service_dir")
    cert_file="$service_dir/${service}.crt"

    if [ -f "$cert_file" ]; then
        echo "=== $service Certificate ==="

        # Check certificate validity
        openssl x509 -in "$cert_file" -text -noout | grep -A 2 "Validity"

        # Verify certificate against CA
        if openssl verify -CAfile "$CA_CERT" "$cert_file" > /dev/null 2>&1; then
            echo "✓ Certificate verification: PASSED"
        else
            echo "✗ Certificate verification: FAILED"
        fi

        # Show subject alternative names
        echo "Subject Alternative Names:"
        openssl x509 -in "$cert_file" -text -noout | grep -A 1 "Subject Alternative Name" || echo "  None"

        echo ""
    fi
done

echo "Validation completed!"
EOF

    chmod +x "$SSL_DIR/validate-certificates.sh"

    print_success "Certificate validation script created"
}

create_renewal_script() {
    print_step "Creating certificate renewal script..."

    cat > "$SSL_DIR/renew-certificates.sh" << 'EOF'
#!/bin/bash

# Renew service certificates (keep same CA)
# Run this before certificates expire

set -e

SSL_DIR="$(pwd)/ssl-certificates"
CA_DIR="$SSL_DIR/ca"
SERVICES_DIR="$SSL_DIR/services"
CONFIG_DIR="$(pwd)/ssl-config"
SERVICE_VALIDITY=365

# Services to renew
SERVICES=(
    "cms-api"
    "go-api"
    "skins-service"
    "email-service"
    "admin-panel"
    "webapp"
    "nginx"
    "redis"
    "postgres"
    "mysql"
    "sqlserver"
    "prometheus"
    "grafana"
)

echo "=== Certificate Renewal Process ==="
echo ""

for service in "${SERVICES[@]}"; do
    service_dir="$SERVICES_DIR/$service"

    if [ -d "$service_dir" ]; then
        echo "Renewing certificate for $service..."

        # Backup old certificate
        if [ -f "$service_dir/$service.crt" ]; then
            cp "$service_dir/$service.crt" "$service_dir/$service.crt.backup"
        fi

        # Generate new certificate with same key
        openssl req -new -config "$CONFIG_DIR/${service}.conf" \
            -key "$service_dir/$service.key" \
            -out "$service_dir/$service.csr"

        # Sign with CA
        openssl x509 -req -in "$service_dir/$service.csr" \
            -CA "$CA_DIR/ca.crt" \
            -CAkey "$CA_DIR/ca.key" \
            -CAcreateserial \
            -out "$service_dir/$service.crt" \
            -days $SERVICE_VALIDITY \
            -extensions v3_req \
            -extfile "$CONFIG_DIR/${service}.conf"

        # Update bundle
        cat "$service_dir/$service.crt" "$CA_DIR/ca.crt" > "$service_dir/${service}-bundle.crt"

        # Update full PEM
        cat "$service_dir/$service.key" "$service_dir/$service.crt" "$CA_DIR/ca.crt" > "$service_dir/${service}-full.pem"

        # Clean up
        rm "$service_dir/$service.csr"

        echo "✓ $service certificate renewed"
    fi
done

echo ""
echo "Certificate renewal completed!"
echo "Remember to restart services to load new certificates."
EOF

    chmod +x "$SSL_DIR/renew-certificates.sh"

    print_success "Certificate renewal script created"
}

generate_dhparam() {
    print_step "Generating Diffie-Hellman parameters..."

    # Generate strong DH parameters for perfect forward secrecy
    openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048
    chmod 644 "$SSL_DIR/dhparam.pem"

    print_success "DH parameters generated"
}

create_ssl_config_templates() {
    print_step "Creating SSL configuration templates..."

    # Nginx SSL configuration
    cat > "$SSL_DIR/nginx-ssl.conf" << 'EOF'
# Strong SSL Configuration for Nginx
# Include this in your nginx configuration

# SSL protocols and ciphers
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers on;
ssl_ecdh_curve secp384r1;

# SSL session settings
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;

# DH parameters
ssl_dhparam /etc/ssl/certs/dhparam.pem;

# OCSP stapling
ssl_stapling on;
ssl_stapling_verify on;

# Security headers
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Content-Type-Options nosniff always;
add_header X-Frame-Options DENY always;
add_header X-XSS-Protection "1; mode=block" always;

# Certificate paths (update these)
ssl_certificate /etc/ssl/certs/nginx.crt;
ssl_certificate_key /etc/ssl/private/nginx.key;
ssl_trusted_certificate /etc/ssl/certs/ca.crt;
EOF

    # C# API SSL configuration template
    cat > "$SSL_DIR/appsettings-ssl.json" << 'EOF'
{
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:80"
      },
      "Https": {
        "Url": "https://0.0.0.0:443",
        "Certificate": {
          "Path": "/app/ssl/cms-api.crt",
          "KeyPath": "/app/ssl/cms-api.key"
        }
      }
    }
  },
  "HttpsRedirection": {
    "RedirectStatusCode": 308,
    "HttpsPort": 443
  },
  "SSL": {
    "RequireHttps": true,
    "ClientCertificateValidation": true,
    "TrustedCA": "/app/ssl/ca.crt"
  }
}
EOF

    print_success "SSL configuration templates created"
}

show_summary() {
    print_success "SSL infrastructure generated successfully!"
    echo ""
    echo -e "${CYAN}=== Generated Files ===${NC}"
    echo -e "${GREEN}CA Certificate:${NC}       $CA_DIR/ca.crt"
    echo -e "${GREEN}CA Private Key:${NC}       $CA_DIR/ca.key"
    echo -e "${GREEN}Service Certificates:${NC} $SERVICES_DIR/"
    echo -e "${GREEN}DH Parameters:${NC}        $SSL_DIR/dhparam.pem"
    echo -e "${GREEN}Management Scripts:${NC}   $SSL_DIR/*.sh"
    echo -e "${GREEN}Config Templates:${NC}     $SSL_DIR/*.conf"
    echo ""
    echo -e "${CYAN}=== Next Steps ===${NC}"
    echo -e "${YELLOW}1.${NC} Distribute certificates to respective services"
    echo -e "${YELLOW}2.${NC} Configure services to use SSL certificates"
    echo -e "${YELLOW}3.${NC} Create Docker/K8s secrets: ${CYAN}$SSL_DIR/create-secrets.sh${NC}"
    echo -e "${YELLOW}4.${NC} Validate certificates: ${CYAN}$SSL_DIR/validate-certificates.sh${NC}"
    echo -e "${YELLOW}5.${NC} Set up certificate renewal automation"
    echo ""
    echo -e "${YELLOW}⚠️  Keep ca.key secure - it's the root of trust!${NC}"
    echo -e "${YELLOW}⚠️  Set up firewall rules for SSL ports${NC}"
    echo -e "${YELLOW}⚠️  Configure certificate renewal before expiration${NC}"
}

main() {
    print_banner

    setup_directories
    create_ca_config
    generate_ca_certificate

    # Generate certificates for all services
    for service in "${SERVICES[@]}"; do
        generate_service_certificate "$service"
    done

    # Generate client certificates for inter-service auth
    generate_client_certificate "internal-client"

    generate_dhparam
    create_docker_secrets
    create_kubernetes_secrets
    create_validation_script
    create_renewal_script
    create_ssl_config_templates

    show_summary
}

# Check for OpenSSL
if ! command -v openssl &> /dev/null; then
    print_error "OpenSSL is required but not installed"
    exit 1
fi

# Run main function
main "$@"