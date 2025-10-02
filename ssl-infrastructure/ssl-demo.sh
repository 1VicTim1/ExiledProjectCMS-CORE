#!/bin/bash

# ExiledProjectCMS SSL Demo Script
# Demonstrates SSL certificate generation and validation

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}${CYAN}         ExiledProjectCMS SSL Demo                   ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${YELLOW}    Interactive SSL Certificate Demonstration       ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

demo_certificate_generation() {
    echo -e "${BLUE}🔐 Demo: SSL Certificate Generation${NC}"
    echo ""
    echo -e "${CYAN}This demo will:${NC}"
    echo "1. Generate a Certificate Authority (CA)"
    echo "2. Create service certificates for all ExiledProjectCMS services"
    echo "3. Generate client certificates for inter-service authentication"
    echo "4. Validate all certificates"
    echo ""

    read -p "Press Enter to start certificate generation..."

    echo -e "\n${YELLOW}Step 1: Generating Certificate Authority...${NC}"
    if [ ! -f "../ssl-certificates/ca/ca.crt" ]; then
        ./generate-certificates.sh
        echo -e "${GREEN}✓ Certificates generated successfully${NC}"
    else
        echo -e "${GREEN}✓ Certificates already exist${NC}"
    fi

    echo -e "\n${YELLOW}Step 2: Validating certificates...${NC}"
    ./ssl-certificates/validate-certificates.sh

    echo -e "\n${GREEN}Certificate generation demo completed!${NC}"
}

demo_ssl_configuration() {
    echo -e "\n${BLUE}⚙️ Demo: SSL Configuration Files${NC}"
    echo ""
    echo -e "${CYAN}Generated SSL configurations:${NC}"
    echo ""

    if [ -f "service-configs/cms-api-ssl.json" ]; then
        echo -e "${GREEN}✓ C# API SSL Configuration:${NC}"
        echo "  - HTTPS endpoints: 8443 (public), 8444 (internal)"
        echo "  - Client certificate validation enabled"
        echo "  - Mutual TLS for internal communication"
        echo ""
    fi

    if [ -f "service-configs/nginx-ssl.conf" ]; then
        echo -e "${GREEN}✓ Nginx SSL Configuration:${NC}"
        echo "  - SSL termination and backend encryption"
        echo "  - Perfect Forward Secrecy (PFS)"
        echo "  - Strong cipher suites"
        echo "  - OCSP stapling enabled"
        echo ""
    fi

    if [ -f "service-configs/redis-ssl.conf" ]; then
        echo -e "${GREEN}✓ Redis SSL Configuration:${NC}"
        echo "  - TLS-only port 6380"
        echo "  - Client certificate authentication"
        echo "  - Strong encryption protocols"
        echo ""
    fi

    echo -e "${GREEN}SSL configuration demo completed!${NC}"
}

demo_security_testing() {
    echo -e "\n${BLUE}🔍 Demo: Security Testing${NC}"
    echo ""
    echo -e "${CYAN}SSL Security Tests:${NC}"
    echo ""

    if [ -f "../ssl-certificates/ca/ca.crt" ]; then
        echo -e "${YELLOW}Testing CA certificate:${NC}"
        openssl x509 -in ../ssl-certificates/ca/ca.crt -text -noout | grep -A 2 "Validity"
        echo ""

        echo -e "${YELLOW}Testing service certificate (cms-api):${NC}"
        if [ -f "../ssl-certificates/services/cms-api/cms-api.crt" ]; then
            openssl x509 -in ../ssl-certificates/services/cms-api/cms-api.crt -text -noout | grep -A 2 "Validity"
            echo ""
            echo "Subject Alternative Names:"
            openssl x509 -in ../ssl-certificates/services/cms-api/cms-api.crt -text -noout | grep -A 1 "Subject Alternative Name" || echo "  None"
            echo ""
        fi

        echo -e "${YELLOW}Certificate chain verification:${NC}"
        if openssl verify -CAfile ../ssl-certificates/ca/ca.crt ../ssl-certificates/services/cms-api/cms-api.crt 2>/dev/null; then
            echo -e "${GREEN}✓ Certificate chain is valid${NC}"
        else
            echo -e "${RED}✗ Certificate chain validation failed${NC}"
        fi
        echo ""
    else
        echo -e "${YELLOW}No certificates found. Run certificate generation first.${NC}"
    fi

    echo -e "${GREEN}Security testing demo completed!${NC}"
}

demo_docker_integration() {
    echo -e "\n${BLUE}🐳 Demo: Docker Integration${NC}"
    echo ""
    echo -e "${CYAN}Docker SSL Integration:${NC}"
    echo ""

    echo -e "${YELLOW}Docker Compose SSL Templates:${NC}"
    if [ -f "../docker-templates/base-ssl.yml" ]; then
        echo -e "${GREEN}✓ Base SSL template${NC}"
    fi
    if [ -f "../docker-templates/cache-redis-ssl.yml" ]; then
        echo -e "${GREEN}✓ Redis SSL template${NC}"
    fi
    if [ -f "../docker-templates/loadbalancer-ssl.yml" ]; then
        echo -e "${GREEN}✓ Nginx SSL template${NC}"
    fi
    echo ""

    echo -e "${YELLOW}Docker Secrets Integration:${NC}"
    if [ -f "../ssl-certificates/create-secrets.sh" ]; then
        echo -e "${GREEN}✓ Docker Swarm secrets script${NC}"
        echo "  Command: ./ssl-certificates/create-secrets.sh"
    fi
    echo ""

    echo -e "${YELLOW}Kubernetes Integration:${NC}"
    if [ -f "../ssl-certificates/create-k8s-secrets.sh" ]; then
        echo -e "${GREEN}✓ Kubernetes secrets script${NC}"
        echo "  Command: ./ssl-certificates/create-k8s-secrets.sh"
    fi
    echo ""

    echo -e "${GREEN}Docker integration demo completed!${NC}"
}

demo_management_tools() {
    echo -e "\n${BLUE}🛠️ Demo: Certificate Management Tools${NC}"
    echo ""
    echo -e "${CYAN}Available Management Scripts:${NC}"
    echo ""

    if [ -f "../ssl-certificates/validate-certificates.sh" ]; then
        echo -e "${GREEN}✓ Certificate Validation:${NC}"
        echo "  Command: ./ssl-certificates/validate-certificates.sh"
        echo "  Purpose: Validate all certificates and verify CA chain"
        echo ""
    fi

    if [ -f "../ssl-certificates/renew-certificates.sh" ]; then
        echo -e "${GREEN}✓ Certificate Renewal:${NC}"
        echo "  Command: ./ssl-certificates/renew-certificates.sh"
        echo "  Purpose: Renew expiring certificates (keep same keys)"
        echo ""
    fi

    echo -e "${YELLOW}Certificate Monitoring:${NC}"
    echo "  - Expiration date checking"
    echo "  - Certificate chain validation"
    echo "  - Automated renewal alerts"
    echo ""

    echo -e "${YELLOW}Production Considerations:${NC}"
    echo "  - Store CA private key securely (consider HSM)"
    echo "  - Set up automated certificate renewal"
    echo "  - Monitor certificate expiration dates"
    echo "  - Regular security audits"
    echo ""

    echo -e "${GREEN}Management tools demo completed!${NC}"
}

show_ssl_architecture() {
    echo -e "\n${BLUE}🏗️ ExiledProjectCMS SSL Architecture${NC}"
    echo ""
    echo -e "${CYAN}SSL Communication Flow:${NC}"
    echo ""
    echo "┌─────────────────┐    HTTPS    ┌─────────────────┐"
    echo "│   Load Balancer │◄────────────►│   Frontend      │"
    echo "│     (Nginx)     │              │   (Vue.js)      │"
    echo "└─────────────────┘              └─────────────────┘"
    echo "         │"
    echo "         ▼ mTLS (mutual TLS)"
    echo "┌─────────────────┐    mTLS     ┌─────────────────┐"
    echo "│   CMS API       │◄────────────►│   Go API        │"
    echo "│   (C# .NET)     │              │   (Gin)         │"
    echo "└─────────────────┘              └─────────────────┘"
    echo "         │                                │"
    echo "         ▼ TLS                           ▼ TLS"
    echo "┌─────────────────┐              ┌─────────────────┐"
    echo "│   Cache         │              │   Database      │"
    echo "│   (Redis TLS)   │              │ (PostgreSQL SSL)│"
    echo "└─────────────────┘              └─────────────────┘"
    echo ""
    echo -e "${YELLOW}Security Features:${NC}"
    echo "• 🔐 End-to-end encryption"
    echo "• 🛡️ Mutual authentication (mTLS)"
    echo "• 🔑 Certificate-based access control"
    echo "• ⚡ Perfect Forward Secrecy (PFS)"
    echo "• 🔄 Automated certificate management"
    echo ""
}

interactive_menu() {
    while true; do
        echo -e "\n${CYAN}Select a demo:${NC}"
        echo "1) 🔐 Certificate Generation"
        echo "2) ⚙️ SSL Configuration Files"
        echo "3) 🔍 Security Testing"
        echo "4) 🐳 Docker Integration"
        echo "5) 🛠️ Management Tools"
        echo "6) 🏗️ SSL Architecture"
        echo "7) 📚 Complete Demo (all of the above)"
        echo "8) Exit"
        echo ""

        read -p "Enter your choice (1-8): " choice

        case $choice in
            1) demo_certificate_generation ;;
            2) demo_ssl_configuration ;;
            3) demo_security_testing ;;
            4) demo_docker_integration ;;
            5) demo_management_tools ;;
            6) show_ssl_architecture ;;
            7)
                demo_certificate_generation
                demo_ssl_configuration
                demo_security_testing
                demo_docker_integration
                demo_management_tools
                show_ssl_architecture
                ;;
            8)
                echo -e "\n${GREEN}Thank you for exploring ExiledProjectCMS SSL features!${NC}"
                exit 0
                ;;
            *)
                echo -e "${YELLOW}Invalid choice. Please select 1-8.${NC}"
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

main() {
    print_banner

    echo -e "${GREEN}Welcome to the ExiledProjectCMS SSL Demo!${NC}"
    echo ""
    echo -e "${CYAN}This interactive demo showcases the comprehensive SSL/TLS${NC}"
    echo -e "${CYAN}implementation for secure inter-service communication.${NC}"
    echo ""

    # Check if OpenSSL is available
    if ! command -v openssl &> /dev/null; then
        echo -e "${YELLOW}⚠️  OpenSSL is required but not installed${NC}"
        echo "Please install OpenSSL to run this demo."
        exit 1
    fi

    interactive_menu
}

# Run the demo
main "$@"