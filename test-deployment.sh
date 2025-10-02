#!/bin/bash

# ExiledProjectCMS Deployment Testing & Validation Script
# Version: 1.0.0
# Tests all APIs, measures performance, and validates deployment

set -euo pipefail

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_VERSION="1.0.0"
readonly INVENTORY_FILE="/var/lib/exiledproject-cms/deployment-inventory.json"
readonly TEST_REPORT_DIR="/var/lib/exiledproject-cms/test-reports"
readonly TEST_TIMEOUT=30

# Test results
declare -A TEST_RESULTS
declare -A PERFORMANCE_RESULTS
declare -A COMPONENT_URLS

# Utility functions
log() {
    local level="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $*"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

print_banner() {
    clear
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    🧪 ExiledProjectCMS Deployment Testing & Validation      ║
║                                                              ║
║    ✅ API Health Checks                                      ║
║    ⚡ Performance Benchmarks                                ║
║    🔍 Security Validation                                   ║
║    📊 Comprehensive Reporting                                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "\n${GREEN}Version: $SCRIPT_VERSION${NC}"
    echo -e "${CYAN}Starting deployment validation...${NC}\n"
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

# Load deployment inventory
load_deployment_inventory() {
    print_step "Loading Deployment Inventory"

    if [[ ! -f "$INVENTORY_FILE" ]]; then
        print_error "Deployment inventory not found: $INVENTORY_FILE"
        print_error "Please run the universal installer first"
        exit 1
    fi

    if ! jq empty "$INVENTORY_FILE" 2>/dev/null; then
        print_error "Invalid JSON in inventory file"
        exit 1
    fi

    print_success "Deployment inventory loaded"

    # Extract component information
    while IFS= read -r component; do
        local host=$(jq -r ".components.\"$component\".host" "$INVENTORY_FILE")
        local status=$(jq -r ".components.\"$component\".status" "$INVENTORY_FILE")

        if [[ "$status" == "deployed" ]]; then
            case "$component" in
                "cms-api")
                    COMPONENT_URLS["cms-api"]="http://$host:5006"
                    ;;
                "go-api")
                    COMPONENT_URLS["go-api"]="http://$host:8080"
                    ;;
                "skins-service")
                    COMPONENT_URLS["skins-service"]="http://$host:8081"
                    ;;
                "email-service")
                    COMPONENT_URLS["email-service"]="http://$host:8082"
                    ;;
                "admin-panel")
                    COMPONENT_URLS["admin-panel"]="http://$host:3000"
                    ;;
                "webapp")
                    COMPONENT_URLS["webapp"]="http://$host:8090"
                    ;;
                "nginx")
                    COMPONENT_URLS["nginx"]="http://$host:80"
                    ;;
                "monitoring")
                    COMPONENT_URLS["prometheus"]="http://$host:9090"
                    COMPONENT_URLS["grafana"]="http://$host:3001"
                    ;;
            esac
        fi
    done < <(jq -r '.components | keys[]' "$INVENTORY_FILE")

    echo "Found ${#COMPONENT_URLS[@]} endpoints to test"
}

# HTTP request with timeout and error handling
make_request() {
    local url="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    local expected_code="${4:-200}"

    local curl_opts=(
        --silent
        --write-out "%{http_code};%{time_total};%{time_namelookup};%{time_connect};%{size_download}"
        --output /tmp/curl_response.tmp
        --max-time "$TEST_TIMEOUT"
        --connect-timeout 10
    )

    if [[ "$method" == "POST" ]] && [[ -n "$data" ]]; then
        curl_opts+=(--data "$data" --header "Content-Type: application/json")
    fi

    local result
    if result=$(curl "${curl_opts[@]}" --request "$method" "$url" 2>/dev/null); then
        local http_code time_total time_namelookup time_connect size_download
        IFS=';' read -r http_code time_total time_namelookup time_connect size_download <<< "$result"

        local response_body=""
        if [[ -f /tmp/curl_response.tmp ]]; then
            response_body=$(cat /tmp/curl_response.tmp)
            rm -f /tmp/curl_response.tmp
        fi

        echo "$http_code|$time_total|$time_namelookup|$time_connect|$size_download|$response_body"
        return 0
    else
        echo "000|0|0|0|0|Connection failed"
        return 1
    fi
}

# Generic API health check
test_api_health() {
    local service_name="$1"
    local base_url="$2"
    local health_endpoint="${3:-/health}"

    print_step "Testing $service_name API Health"

    local url="$base_url$health_endpoint"
    local result
    result=$(make_request "$url" "GET" "" "200")

    local http_code time_total response_body
    IFS='|' read -r http_code time_total _ _ _ response_body <<< "$result"

    if [[ "$http_code" == "200" ]]; then
        TEST_RESULTS["$service_name"]="PASS"
        PERFORMANCE_RESULTS["${service_name}_response_time"]="$time_total"
        print_success "$service_name health check passed (${time_total}s)"

        # Parse health response if JSON
        if echo "$response_body" | jq empty 2>/dev/null; then
            local status=$(echo "$response_body" | jq -r '.status // "unknown"')
            echo "  Status: $status"

            # Extract additional metrics if available
            if echo "$response_body" | jq -e '.uptime' >/dev/null; then
                local uptime=$(echo "$response_body" | jq -r '.uptime')
                echo "  Uptime: $uptime"
            fi
        fi
    else
        TEST_RESULTS["$service_name"]="FAIL"
        print_error "$service_name health check failed (HTTP $http_code)"
        if [[ -n "$response_body" ]]; then
            echo "  Response: $response_body"
        fi
    fi
}

# CMS API specific tests
test_cms_api() {
    local base_url="${COMPONENT_URLS[cms-api]}"
    [[ -z "$base_url" ]] && return

    print_step "Testing CMS API Endpoints"

    # Health check
    test_api_health "cms-api" "$base_url" "/health"

    # Swagger documentation
    local swagger_result
    swagger_result=$(make_request "$base_url/swagger/index.html" "GET" "" "200")
    local swagger_code
    IFS='|' read -r swagger_code _ <<< "$swagger_result"

    if [[ "$swagger_code" == "200" ]]; then
        print_success "Swagger documentation accessible"
    else
        print_warning "Swagger documentation not accessible (HTTP $swagger_code)"
    fi

    # Test authentication endpoint (should return validation error without data)
    local auth_result
    auth_result=$(make_request "$base_url/api/v1/integrations/auth/signin" "POST" '{}' "400")
    local auth_code
    IFS='|' read -r auth_code _ <<< "$auth_result"

    if [[ "$auth_code" == "400" ]]; then
        print_success "Authentication endpoint responding correctly"
    else
        print_warning "Authentication endpoint unexpected response (HTTP $auth_code)"
    fi

    # Test news endpoint
    local news_result
    news_result=$(make_request "$base_url/api/news" "GET" "" "200")
    local news_code news_time news_body
    IFS='|' read -r news_code news_time _ _ _ news_body <<< "$news_result"

    if [[ "$news_code" == "200" ]]; then
        print_success "News endpoint responding (${news_time}s)"

        # Check if response is valid JSON array
        if echo "$news_body" | jq -e 'type == "array"' >/dev/null 2>&1; then
            local news_count=$(echo "$news_body" | jq 'length')
            echo "  News count: $news_count"
        fi
    else
        print_error "News endpoint failed (HTTP $news_code)"
    fi
}

# Go API specific tests
test_go_api() {
    local base_url="${COMPONENT_URLS[go-api]}"
    [[ -z "$base_url" ]] && return

    print_step "Testing Go API Endpoints"

    # Health check
    test_api_health "go-api" "$base_url" "/health"

    # Stats endpoint
    local stats_result
    stats_result=$(make_request "$base_url/api/v1/stats" "GET" "" "200")
    local stats_code stats_time stats_body
    IFS='|' read -r stats_code stats_time _ _ _ stats_body <<< "$stats_result"

    if [[ "$stats_code" == "200" ]]; then
        print_success "Stats endpoint responding (${stats_time}s)"

        if echo "$stats_body" | jq empty 2>/dev/null; then
            echo "  Response: $(echo "$stats_body" | jq -c .)"
        fi
    else
        print_error "Stats endpoint failed (HTTP $stats_code)"
    fi

    # Metrics endpoint
    local metrics_result
    metrics_result=$(make_request "$base_url/api/v1/metrics" "GET" "" "200")
    local metrics_code
    IFS='|' read -r metrics_code _ <<< "$metrics_result"

    if [[ "$metrics_code" == "200" ]]; then
        print_success "Metrics endpoint responding"
    else
        print_error "Metrics endpoint failed (HTTP $metrics_code)"
    fi
}

# Skins service specific tests
test_skins_service() {
    local base_url="${COMPONENT_URLS[skins-service]}"
    [[ -z "$base_url" ]] && return

    print_step "Testing Skins Service Endpoints"

    # Health check
    test_api_health "skins-service" "$base_url" "/health"

    # Test profile endpoint with dummy UUID
    local test_uuid="550e8400-e29b-41d4-a716-446655440000"
    local profile_result
    profile_result=$(make_request "$base_url/api/v1/profile/$test_uuid" "GET" "" "200")
    local profile_code profile_time
    IFS='|' read -r profile_code profile_time _ <<< "$profile_result"

    if [[ "$profile_code" == "200" ]]; then
        print_success "Profile endpoint responding (${profile_time}s)"
    else
        print_warning "Profile endpoint returned HTTP $profile_code (expected for non-existent profile)"
    fi

    # Test avatar endpoint
    local avatar_result
    avatar_result=$(make_request "$base_url/api/v1/avatar/$test_uuid" "GET" "" "200")
    local avatar_code
    IFS='|' read -r avatar_code _ <<< "$avatar_result"

    if [[ "$avatar_code" == "200" ]]; then
        print_success "Avatar endpoint responding"
    else
        print_warning "Avatar endpoint returned HTTP $avatar_code"
    fi

    # Test admin stats
    local stats_result
    stats_result=$(make_request "$base_url/api/v1/admin/stats" "GET" "" "200")
    local stats_code stats_body
    IFS='|' read -r stats_code _ _ _ _ stats_body <<< "$stats_result"

    if [[ "$stats_code" == "200" ]]; then
        print_success "Admin stats endpoint responding"
        if echo "$stats_body" | jq empty 2>/dev/null; then
            local total_skins=$(echo "$stats_body" | jq -r '.total_skins // 0')
            local total_capes=$(echo "$stats_body" | jq -r '.total_capes // 0')
            echo "  Total skins: $total_skins"
            echo "  Total capes: $total_capes"
        fi
    else
        print_error "Admin stats endpoint failed (HTTP $stats_code)"
    fi
}

# Email service test
test_email_service() {
    local base_url="${COMPONENT_URLS[email-service]}"
    [[ -z "$base_url" ]] && return

    print_step "Testing Email Service"

    # Health check
    test_api_health "email-service" "$base_url" "/health"

    # Note: We don't test actual email sending to avoid spam
    print_success "Email service health check completed"
}

# Frontend tests
test_frontend_services() {
    # Admin panel
    if [[ -n "${COMPONENT_URLS[admin-panel]:-}" ]]; then
        print_step "Testing Admin Panel"

        local admin_result
        admin_result=$(make_request "${COMPONENT_URLS[admin-panel]}" "GET" "" "200")
        local admin_code
        IFS='|' read -r admin_code _ <<< "$admin_result"

        if [[ "$admin_code" == "200" ]]; then
            TEST_RESULTS["admin-panel"]="PASS"
            print_success "Admin panel accessible"
        else
            TEST_RESULTS["admin-panel"]="FAIL"
            print_error "Admin panel not accessible (HTTP $admin_code)"
        fi
    fi

    # Web app
    if [[ -n "${COMPONENT_URLS[webapp]:-}" ]]; then
        print_step "Testing Web App"

        local webapp_result
        webapp_result=$(make_request "${COMPONENT_URLS[webapp]}" "GET" "" "200")
        local webapp_code
        IFS='|' read -r webapp_code _ <<< "$webapp_result"

        if [[ "$webapp_code" == "200" ]]; then
            TEST_RESULTS["webapp"]="PASS"
            print_success "Web app accessible"
        else
            TEST_RESULTS["webapp"]="FAIL"
            print_error "Web app not accessible (HTTP $webapp_code)"
        fi
    fi
}

# Load balancer test
test_load_balancer() {
    local base_url="${COMPONENT_URLS[nginx]}"
    [[ -z "$base_url" ]] && return

    print_step "Testing Load Balancer"

    # Test root endpoint
    local nginx_result
    nginx_result=$(make_request "$base_url" "GET" "" "200")
    local nginx_code nginx_time
    IFS='|' read -r nginx_code nginx_time _ <<< "$nginx_result"

    if [[ "$nginx_code" == "200" ]] || [[ "$nginx_code" == "301" ]] || [[ "$nginx_code" == "302" ]]; then
        TEST_RESULTS["nginx"]="PASS"
        print_success "Load balancer responding (${nginx_time}s)"
    else
        TEST_RESULTS["nginx"]="FAIL"
        print_error "Load balancer failed (HTTP $nginx_code)"
    fi

    # Test if it properly routes to backend services
    if [[ -n "${COMPONENT_URLS[cms-api]:-}" ]]; then
        print_step "Testing Load Balancer Routing"

        # Assuming nginx routes /api to cms-api
        local route_result
        route_result=$(make_request "$base_url/api/news" "GET" "" "200")
        local route_code
        IFS='|' read -r route_code _ <<< "$route_result"

        if [[ "$route_code" == "200" ]]; then
            print_success "Load balancer routing working"
        else
            print_warning "Load balancer routing may need configuration (HTTP $route_code)"
        fi
    fi
}

# Monitoring services test
test_monitoring_services() {
    # Prometheus
    if [[ -n "${COMPONENT_URLS[prometheus]:-}" ]]; then
        print_step "Testing Prometheus"

        local prom_result
        prom_result=$(make_request "${COMPONENT_URLS[prometheus]}" "GET" "" "200")
        local prom_code
        IFS='|' read -r prom_code _ <<< "$prom_result"

        if [[ "$prom_code" == "200" ]]; then
            TEST_RESULTS["prometheus"]="PASS"
            print_success "Prometheus accessible"
        else
            TEST_RESULTS["prometheus"]="FAIL"
            print_error "Prometheus not accessible (HTTP $prom_code)"
        fi
    fi

    # Grafana
    if [[ -n "${COMPONENT_URLS[grafana]:-}" ]]; then
        print_step "Testing Grafana"

        local grafana_result
        grafana_result=$(make_request "${COMPONENT_URLS[grafana]}" "GET" "" "200")
        local grafana_code
        IFS='|' read -r grafana_code _ <<< "$grafana_result"

        if [[ "$grafana_code" == "200" ]] || [[ "$grafana_code" == "302" ]]; then
            TEST_RESULTS["grafana"]="PASS"
            print_success "Grafana accessible"
        else
            TEST_RESULTS["grafana"]="FAIL"
            print_error "Grafana not accessible (HTTP $grafana_code)"
        fi
    fi
}

# Performance benchmarking
run_performance_tests() {
    print_step "Running Performance Benchmarks"

    for service in "${!COMPONENT_URLS[@]}"; do
        local url="${COMPONENT_URLS[$service]}"
        local endpoint="/"

        # Choose appropriate endpoint for each service
        case "$service" in
            "cms-api") endpoint="/health" ;;
            "go-api") endpoint="/api/v1/stats" ;;
            "skins-service") endpoint="/health" ;;
            "email-service") endpoint="/health" ;;
            *) endpoint="/" ;;
        esac

        print_step "Benchmarking $service"

        # Run multiple requests to get average performance
        local total_time=0
        local successful_requests=0
        local failed_requests=0

        for i in {1..10}; do
            local result
            result=$(make_request "$url$endpoint" "GET" "" "200")
            local http_code time_total
            IFS='|' read -r http_code time_total _ <<< "$result"

            if [[ "$http_code" == "200" ]]; then
                total_time=$(echo "$total_time + $time_total" | bc)
                ((successful_requests++))
            else
                ((failed_requests++))
            fi
        done

        if [[ $successful_requests -gt 0 ]]; then
            local avg_time=$(echo "scale=3; $total_time / $successful_requests" | bc)
            PERFORMANCE_RESULTS["${service}_avg_response"]="$avg_time"
            PERFORMANCE_RESULTS["${service}_success_rate"]=$(echo "scale=2; $successful_requests * 100 / 10" | bc)

            echo "  Average response time: ${avg_time}s"
            echo "  Success rate: ${PERFORMANCE_RESULTS[${service}_success_rate]}%"
        else
            echo "  All requests failed"
        fi
    done
}

# Security validation
run_security_tests() {
    print_step "Running Security Validation"

    # Test for common security headers
    for service in "${!COMPONENT_URLS[@]}"; do
        local url="${COMPONENT_URLS[$service]}"

        print_step "Security check: $service"

        # Check response headers
        local headers
        headers=$(curl -I -s --max-time 10 "$url" 2>/dev/null || true)

        # Check for security headers
        if echo "$headers" | grep -qi "X-Frame-Options"; then
            echo "  ✓ X-Frame-Options header present"
        else
            echo "  ⚠ X-Frame-Options header missing"
        fi

        if echo "$headers" | grep -qi "X-Content-Type-Options"; then
            echo "  ✓ X-Content-Type-Options header present"
        else
            echo "  ⚠ X-Content-Type-Options header missing"
        fi

        # Test for information disclosure
        local response
        response=$(make_request "$url/nonexistent-endpoint-test" "GET" "" "404")
        local error_code error_body
        IFS='|' read -r error_code _ _ _ _ error_body <<< "$response"

        if [[ "$error_code" == "404" ]]; then
            echo "  ✓ Proper 404 handling"

            # Check if error response reveals too much information
            if echo "$error_body" | grep -qi "stack trace\|exception\|debug\|internal error"; then
                echo "  ⚠ Error responses may reveal too much information"
            else
                echo "  ✓ Error responses don't reveal sensitive information"
            fi
        fi
    done
}

# Docker container health
check_container_health() {
    print_step "Checking Docker Container Health"

    # Check if docker-compose file exists
    if [[ -f "docker-compose.generated.yml" ]]; then
        local containers
        containers=$(docker-compose -f docker-compose.generated.yml ps --format "table {{.Name}}\t{{.State}}\t{{.Ports}}" 2>/dev/null || echo "")

        if [[ -n "$containers" ]]; then
            echo "$containers"

            # Count healthy vs unhealthy containers
            local total_containers
            total_containers=$(docker-compose -f docker-compose.generated.yml ps -q | wc -l)
            local running_containers
            running_containers=$(docker-compose -f docker-compose.generated.yml ps --filter "status=running" -q | wc -l)

            echo "Container status: $running_containers/$total_containers running"

            if [[ "$running_containers" == "$total_containers" ]]; then
                print_success "All containers are running"
            else
                print_warning "Some containers are not running"
            fi
        else
            print_warning "No containers found or docker-compose file missing"
        fi
    else
        print_warning "docker-compose.generated.yml not found"
    fi
}

# Generate test report
generate_test_report() {
    print_step "Generating Test Report"

    mkdir -p "$TEST_REPORT_DIR"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local json_report="$TEST_REPORT_DIR/test-report-$timestamp.json"
    local html_report="$TEST_REPORT_DIR/test-report-$timestamp.html"

    # JSON Report
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
        echo "  \"version\": \"$SCRIPT_VERSION\","
        echo "  \"test_results\": {"

        local first=true
        for service in "${!TEST_RESULTS[@]}"; do
            [[ "$first" == true ]] && first=false || echo ","
            echo -n "    \"$service\": \"${TEST_RESULTS[$service]}\""
        done

        echo ""
        echo "  },"
        echo "  \"performance_results\": {"

        first=true
        for metric in "${!PERFORMANCE_RESULTS[@]}"; do
            [[ "$first" == true ]] && first=false || echo ","
            echo -n "    \"$metric\": \"${PERFORMANCE_RESULTS[$metric]}\""
        done

        echo ""
        echo "  },"
        echo "  \"component_urls\": {"

        first=true
        for component in "${!COMPONENT_URLS[@]}"; do
            [[ "$first" == true ]] && first=false || echo ","
            echo -n "    \"$component\": \"${COMPONENT_URLS[$component]}\""
        done

        echo ""
        echo "  }"
        echo "}"
    } > "$json_report"

    # HTML Report
    {
        cat << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>ExiledProjectCMS Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; margin-bottom: 30px; }
        .section { margin-bottom: 30px; }
        .pass { color: green; font-weight: bold; }
        .fail { color: red; font-weight: bold; }
        .warn { color: orange; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
EOF

        echo "<div class='header'>"
        echo "<h1>🧪 ExiledProjectCMS Test Report</h1>"
        echo "<p><strong>Generated:</strong> $(date)</p>"
        echo "<p><strong>Version:</strong> $SCRIPT_VERSION</p>"
        echo "</div>"

        echo "<div class='section'>"
        echo "<h2>Test Results Summary</h2>"
        echo "<table>"
        echo "<tr><th>Service</th><th>Status</th><th>URL</th></tr>"

        for service in "${!TEST_RESULTS[@]}"; do
            local status="${TEST_RESULTS[$service]}"
            local css_class="pass"
            [[ "$status" == "FAIL" ]] && css_class="fail"

            local url="${COMPONENT_URLS[$service]:-N/A}"
            echo "<tr><td>$service</td><td class='$css_class'>$status</td><td>$url</td></tr>"
        done

        echo "</table>"
        echo "</div>"

        echo "<div class='section'>"
        echo "<h2>Performance Metrics</h2>"
        echo "<table>"
        echo "<tr><th>Metric</th><th>Value</th></tr>"

        for metric in "${!PERFORMANCE_RESULTS[@]}"; do
            echo "<tr><td>$metric</td><td>${PERFORMANCE_RESULTS[$metric]}</td></tr>"
        done

        echo "</table>"
        echo "</div>"

        echo "</body></html>"
    } > "$html_report"

    print_success "Test reports generated:"
    echo "  JSON: $json_report"
    echo "  HTML: $html_report"
}

# Summary display
display_summary() {
    print_step "Test Summary"

    local total_tests=${#TEST_RESULTS[@]}
    local passed_tests=0
    local failed_tests=0

    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" == "PASS" ]]; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                    DEPLOYMENT VALIDATION SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ $failed_tests -eq 0 ]]; then
        print_success "All tests passed! ($passed_tests/$total_tests)"
        echo -e "${GREEN}🎉 Deployment is healthy and ready for use${NC}"
    elif [[ $passed_tests -gt $failed_tests ]]; then
        print_warning "Most tests passed ($passed_tests/$total_tests)"
        echo -e "${YELLOW}⚠️  Some services need attention${NC}"
    else
        print_error "Multiple test failures ($failed_tests/$total_tests failed)"
        echo -e "${RED}❌ Deployment needs investigation${NC}"
    fi

    echo ""
    echo "Detailed results:"
    for service in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[$service]}"
        local status_icon="✅"
        [[ "$result" == "FAIL" ]] && status_icon="❌"

        local url="${COMPONENT_URLS[$service]:-}"
        echo "  $status_icon $service: $result $([ -n "$url" ] && echo "($url)")"
    done

    echo ""
}

# Main execution
main() {
    print_banner

    # Check if running as root (for file access)
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. Consider running as the service user."
    fi

    # Load deployment information
    load_deployment_inventory

    # Run tests
    [[ -n "${COMPONENT_URLS[cms-api]:-}" ]] && test_cms_api
    [[ -n "${COMPONENT_URLS[go-api]:-}" ]] && test_go_api
    [[ -n "${COMPONENT_URLS[skins-service]:-}" ]] && test_skins_service
    [[ -n "${COMPONENT_URLS[email-service]:-}" ]] && test_email_service

    test_frontend_services
    [[ -n "${COMPONENT_URLS[nginx]:-}" ]] && test_load_balancer
    test_monitoring_services

    # Additional validation
    run_performance_tests
    run_security_tests
    check_container_health

    # Reporting
    generate_test_report
    display_summary

    log_info "Deployment testing completed"
}

# Cleanup function
cleanup() {
    rm -f /tmp/curl_response.tmp
}

trap cleanup EXIT

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi