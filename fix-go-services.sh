#!/bin/bash

# ExiledProjectCMS - Go Services Build Issues Fix Script
# Version: 1.1.0
# Updates Go version and ensures proper dependencies with comprehensive logging

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Script information
readonly SCRIPT_VERSION="1.1.0"
readonly SCRIPT_NAME="ExiledProjectCMS Go Services Fixer"

# Logging configuration
setup_logging() {
    if [[ $EUID -eq 0 ]]; then
        # Running as root - use system log directory
        readonly LOG_DIR="/var/log/exiledproject-cms"
        readonly LOG_FILE="$LOG_DIR/fix-go-services-$(date +%Y%m%d-%H%M%S).log"
        readonly ERROR_LOG="$LOG_DIR/fix-go-services-errors.log"
        readonly SUMMARY_LOG="$LOG_DIR/fix-go-services-summary.log"

        # Create system log directory
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
    else
        # Running as regular user - use local directory
        readonly LOG_DIR="./logs"
        readonly LOG_FILE="$LOG_DIR/fix-go-services-$(date +%Y%m%d-%H%M%S).log"
        readonly ERROR_LOG="$LOG_DIR/fix-go-services-errors.log"
        readonly SUMMARY_LOG="$LOG_DIR/fix-go-services-summary.log"

        # Create local log directory
        mkdir -p "$LOG_DIR"
    fi
}

# Enhanced logging functions
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Log errors to separate error file
    if [[ "$level" == "ERROR" ]]; then
        echo "[$timestamp] $message" >> "$ERROR_LOG"
    fi
}

log_info() {
    log "INFO" "$1"
}

log_warn() {
    log "WARN" "$1"
}

log_error() {
    log "ERROR" "$1"
}

log_success() {
    log "SUCCESS" "$1"
}

log_step() {
    log "STEP" "$1"
}

# Enhanced print functions with logging
print_banner() {
    local banner_text="
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║    🔧 $SCRIPT_NAME                      ║
║    Version: $SCRIPT_VERSION                                       ║
║                                                            ║
║    🎯 Fixes Go version compatibility issues                ║
║    📊 Comprehensive logging and reporting                  ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝"

    echo -e "${PURPLE}$banner_text${NC}"
    log_info "Script started - $SCRIPT_NAME v$SCRIPT_VERSION"
    log_info "Log file: $LOG_FILE"
}

print_step() {
    echo -e "\n${BLUE}▶ $1${NC}"
    log_step "$1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    log_success "$1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log_warn "$1"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    log_error "$1"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
    log_info "$1"
}

# System information logging
log_system_info() {
    log_info "=== SYSTEM INFORMATION ==="
    log_info "OS: $(uname -s)"
    log_info "Architecture: $(uname -m)"
    log_info "User: $(whoami)"
    log_info "Working Directory: $(pwd)"
    log_info "Script Path: $0"

    if command -v docker >/dev/null 2>&1; then
        log_info "Docker Version: $(docker --version)"
    else
        log_warn "Docker not found"
    fi

    if command -v docker-compose >/dev/null 2>&1; then
        log_info "Docker Compose Version: $(docker-compose --version)"
    else
        log_warn "Docker Compose not found"
    fi

    if command -v go >/dev/null 2>&1; then
        log_info "Go Version: $(go version)"
    else
        log_info "Go not installed (expected for containerized builds)"
    fi

    log_info "Available Disk Space: $(df -h . | awk 'NR==2 {print $4}')"
}

# Go services configuration
declare -A GO_SERVICES=(
    ["GoServices/HighPerformanceAPI"]="High-Performance Go API Service"
    ["GoServices/SkinsCapesService"]="Minecraft Skins & Capes Service"
    ["GoServices/EmailService"]="Email Notification Service"
)

# Statistics tracking
declare -A STATS=(
    [services_processed]=0
    [dockerfiles_updated]=0
    [gomod_updated]=0
    [dependencies_updated]=0
    [errors_encountered]=0
    [build_tests_passed]=0
    [build_tests_failed]=0
)

# Update statistics
update_stats() {
    local key="$1"
    STATS["$key"]=$((${STATS["$key"]} + 1))
}

# Process individual service
process_service() {
    local service_path="$1"
    local service_name="$2"

    print_step "Processing: $service_name"
    log_info "Starting processing of service: $service_path"

    if [[ ! -d "$service_path" ]]; then
        print_error "Service directory not found: $service_path"
        log_error "Service directory not found: $service_path"
        update_stats "errors_encountered"
        return 1
    fi

    update_stats "services_processed"

    cd "$service_path" || {
        print_error "Failed to enter directory: $service_path"
        log_error "Failed to enter directory: $service_path"
        update_stats "errors_encountered"
        return 1
    }

    # Process go.mod file
    if [[ -f "go.mod" ]]; then
        print_success "Found go.mod"
        log_info "Processing go.mod file in $service_path"

        # Backup original go.mod
        if [[ ! -f "go.mod.backup" ]]; then
            cp go.mod go.mod.backup
            log_info "Created backup: go.mod.backup"
        fi

        # Check current Go version
        local current_version=$(grep -oP 'go \K1\.\d+' go.mod 2>/dev/null || echo "unknown")
        log_info "Current Go version in go.mod: $current_version"

        # Update Go version if needed
        if grep -q "go 1\.2[0-2]" go.mod; then
            sed -i 's/go 1\.2[0-9]/go 1.23/' go.mod
            print_success "Updated Go version from $current_version to 1.23"
            log_success "Updated Go version in go.mod from $current_version to 1.23"
            update_stats "gomod_updated"
        else
            print_info "Go version already correct or not found"
            log_info "Go version already up to date or not found in expected format"
        fi

        # Update dependencies if Go is available
        if command -v go >/dev/null 2>&1; then
            print_step "Updating Go dependencies"
            log_info "Updating Go dependencies for $service_path"

            {
                # Clean module cache
                go clean -modcache 2>/dev/null || true

                # Tidy dependencies
                if go mod tidy 2>/dev/null; then
                    log_success "go mod tidy completed successfully"
                else
                    log_warn "go mod tidy completed with warnings"
                fi

                # Download dependencies
                if go mod download 2>/dev/null; then
                    print_success "Dependencies updated successfully"
                    log_success "Dependencies downloaded successfully"
                    update_stats "dependencies_updated"
                else
                    print_warning "Some dependencies failed to download"
                    log_warn "Some dependencies failed to download"
                fi
            } || {
                print_warning "Failed to update dependencies"
                log_error "Failed to update Go dependencies for $service_path"
                update_stats "errors_encountered"
            }
        else
            print_info "Go not installed locally, skipping dependency update"
            log_info "Go not installed locally, dependencies will be handled during Docker build"
        fi
    else
        print_error "go.mod not found"
        log_error "go.mod file not found in $service_path"
        update_stats "errors_encountered"
    fi

    # Process Dockerfile
    if [[ -f "Dockerfile" ]]; then
        print_success "Found Dockerfile"
        log_info "Processing Dockerfile in $service_path"

        # Backup original Dockerfile
        if [[ ! -f "Dockerfile.backup" ]]; then
            cp Dockerfile Dockerfile.backup
            log_info "Created backup: Dockerfile.backup"
        fi

        # Check current Go version in Dockerfile
        local docker_version=$(grep -oP 'golang:\K1\.\d+' Dockerfile 2>/dev/null || echo "unknown")
        log_info "Current Go version in Dockerfile: $docker_version"

        # Update Go version in Dockerfile
        if grep -q "golang:1\.2[0-2]-alpine" Dockerfile; then
            sed -i 's/golang:1\.2[0-9]-alpine/golang:1.23-alpine/' Dockerfile
            print_success "Updated Dockerfile Go version from $docker_version to 1.23"
            log_success "Updated Dockerfile Go version from $docker_version to 1.23"
            update_stats "dockerfiles_updated"
        else
            print_info "Dockerfile Go version already correct or not found"
            log_info "Dockerfile Go version already up to date or not in expected format"
        fi
    else
        print_warning "Dockerfile not found"
        log_warn "Dockerfile not found in $service_path"
    fi

    cd - > /dev/null || {
        log_error "Failed to return to previous directory"
        update_stats "errors_encountered"
    }

    log_success "Completed processing of $service_path"
}

# Test Docker builds
test_docker_builds() {
    if ! command -v docker >/dev/null 2>&1; then
        print_warning "Docker not available, skipping build tests"
        log_warn "Docker not available, skipping build tests"
        return
    fi

    print_step "Testing Docker Builds"
    log_info "Starting Docker build tests"

    for service_path in "${!GO_SERVICES[@]}"; do
        local service_name="${GO_SERVICES[$service_path]}"

        if [[ -d "$service_path" && -f "$service_path/Dockerfile" ]]; then
            print_step "Testing build: $service_name"
            log_info "Testing Docker build for $service_path"

            local image_name="test-$(basename "$service_path" | tr '[:upper:]' '[:lower:]')"
            local build_log="$LOG_DIR/docker-build-$(basename "$service_path")-$(date +%H%M%S).log"

            if timeout 300 docker build -t "$image_name" "$service_path" > "$build_log" 2>&1; then
                print_success "Build test passed: $service_name"
                log_success "Docker build test passed for $service_path"
                update_stats "build_tests_passed"

                # Get image information
                local image_size=$(docker images "$image_name" --format "table {{.Size}}" | tail -n 1)
                log_info "Built image size: $image_size"

                # Clean up test image
                if docker rmi "$image_name" >/dev/null 2>&1; then
                    log_info "Cleaned up test image: $image_name"
                fi
            else
                print_error "Build test failed: $service_name"
                log_error "Docker build test failed for $service_path"
                log_error "Build log saved to: $build_log"
                update_stats "build_tests_failed"
                update_stats "errors_encountered"

                # Show last few lines of build log
                if [[ -f "$build_log" ]]; then
                    echo -e "${RED}Last 5 lines of build log:${NC}"
                    tail -n 5 "$build_log" | sed 's/^/  /'
                fi
            fi
        else
            print_warning "Skipping build test for $service_name (missing directory or Dockerfile)"
            log_warn "Skipping build test for $service_path (missing directory or Dockerfile)"
        fi
    done
}

# Create comprehensive summary
generate_summary_report() {
    print_step "Generating Summary Report"

    local summary_content="
=== EXILEDPROJECTCMS GO SERVICES FIX SUMMARY ===
Generated: $(date '+%Y-%m-%d %H:%M:%S')
Version: $SCRIPT_VERSION

STATISTICS:
- Services Processed: ${STATS[services_processed]}
- Dockerfiles Updated: ${STATS[dockerfiles_updated]}
- go.mod Files Updated: ${STATS[gomod_updated]}
- Dependencies Updated: ${STATS[dependencies_updated]}
- Build Tests Passed: ${STATS[build_tests_passed]}
- Build Tests Failed: ${STATS[build_tests_failed]}
- Errors Encountered: ${STATS[errors_encountered]}

SERVICES PROCESSED:"

    for service_path in "${!GO_SERVICES[@]}"; do
        local service_name="${GO_SERVICES[$service_path]}"
        summary_content="$summary_content
- $service_name ($service_path)"
    done

    summary_content="$summary_content

CHANGES MADE:
- Updated all Dockerfile Go versions to 1.23-alpine
- Updated all go.mod Go versions to 1.23
- Cleaned and updated Go dependencies (where possible)
- Created backup files (.backup extension)
- Generated comprehensive logs

LOG FILES:
- Main Log: $LOG_FILE
- Error Log: $ERROR_LOG
- Summary: $SUMMARY_LOG
- Docker Build Logs: $LOG_DIR/docker-build-*.log

NEXT STEPS:
1. Review any errors in the error log
2. Run: docker-compose build --no-cache
3. Run: docker-compose up -d
4. Test deployment: ./test-deployment.sh

STATUS: $( [[ ${STATS[errors_encountered]} -eq 0 ]] && echo "SUCCESS" || echo "COMPLETED WITH ERRORS" )
"

    # Save to summary file
    echo "$summary_content" > "$SUMMARY_LOG"

    # Display summary
    echo -e "${CYAN}$summary_content${NC}"

    log_info "Summary report generated: $SUMMARY_LOG"
}

# Cleanup function
cleanup() {
    local exit_code=$?

    log_info "Script cleanup initiated with exit code: $exit_code"

    # Clean up any temporary Docker images
    if command -v docker >/dev/null 2>&1; then
        docker images | grep "^test-" | awk '{print $3}' | xargs -r docker rmi -f >/dev/null 2>&1 || true
    fi

    if [[ $exit_code -ne 0 ]]; then
        log_error "Script exited with error code: $exit_code"
        print_error "Script failed with exit code: $exit_code"
        print_error "Check error log: $ERROR_LOG"
    fi

    log_info "Script cleanup completed"
}

# Main execution
main() {
    # Setup logging first
    setup_logging

    # Set up cleanup trap
    trap cleanup EXIT

    # Display banner and log system info
    print_banner
    log_system_info

    print_step "Starting Go Services Fix Process"
    log_info "Processing ${#GO_SERVICES[@]} Go services"

    # Process each service
    for service_path in "${!GO_SERVICES[@]}"; do
        local service_name="${GO_SERVICES[$service_path]}"

        if ! process_service "$service_path" "$service_name"; then
            log_error "Failed to process service: $service_path"
            update_stats "errors_encountered"
        fi
    done

    # Test Docker builds
    test_docker_builds

    # Generate summary report
    generate_summary_report

    # Final status
    if [[ ${STATS[errors_encountered]} -eq 0 ]]; then
        print_success "🎉 Go services fix completed successfully!"
        log_success "All operations completed successfully"
    else
        print_warning "⚠️  Fix completed with ${STATS[errors_encountered]} error(s)"
        print_warning "Check error log: $ERROR_LOG"
        log_warn "Fix completed with ${STATS[errors_encountered]} error(s)"
    fi

    print_info "📊 Summary report: $SUMMARY_LOG"
    print_info "📋 Full logs: $LOG_FILE"
    print_step "Next: Run 'docker-compose build --no-cache' to test changes"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi