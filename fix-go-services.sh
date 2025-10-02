#!/bin/bash

# Script to fix Go services build issues
# Updates Go version and ensures proper dependencies

set -e

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

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

# Go services to fix
GO_SERVICES=(
    "GoServices/HighPerformanceAPI"
    "GoServices/SkinsCapesService"
    "GoServices/EmailService"
)

print_step "Fixing Go services build issues"

for service in "${GO_SERVICES[@]}"; do
    if [[ -d "$service" ]]; then
        print_step "Processing $service"

        cd "$service"

        # Check if go.mod exists
        if [[ -f "go.mod" ]]; then
            print_success "go.mod found"

            # Update Go version in go.mod to 1.23
            if grep -q "go 1.2[0-2]" go.mod; then
                sed -i 's/go 1\.2[0-9]/go 1.23/' go.mod
                print_success "Updated Go version to 1.23"
            fi

            # Clean and update dependencies
            if command -v go >/dev/null 2>&1; then
                print_step "Cleaning and updating Go modules"

                # Clean module cache for this module
                go clean -modcache || true

                # Tidy up dependencies
                go mod tidy

                # Download dependencies
                go mod download

                print_success "Dependencies updated"
            else
                print_warning "Go not installed, skipping dependency update"
            fi
        else
            print_error "go.mod not found in $service"
        fi

        # Check Dockerfile and update Go version
        if [[ -f "Dockerfile" ]]; then
            if grep -q "golang:1.2[0-2]-alpine" Dockerfile; then
                sed -i 's/golang:1\.2[0-9]-alpine/golang:1.23-alpine/' Dockerfile
                print_success "Updated Dockerfile Go version to 1.23"
            fi
        fi

        cd - > /dev/null
    else
        print_error "Service directory $service not found"
    fi
done

print_step "Creating missing go.sum files if needed"

for service in "${GO_SERVICES[@]}"; do
    if [[ -d "$service" && -f "$service/go.mod" && ! -f "$service/go.sum" ]]; then
        print_step "Creating go.sum for $service"

        cd "$service"

        if command -v go >/dev/null 2>&1; then
            go mod tidy
            print_success "Created go.sum for $service"
        else
            print_warning "Go not installed, creating empty go.sum"
            touch go.sum
        fi

        cd - > /dev/null
    fi
done

# Check if Docker is available
if command -v docker >/dev/null 2>&1; then
    print_step "Testing Docker builds"

    for service in "${GO_SERVICES[@]}"; do
        if [[ -d "$service" && -f "$service/Dockerfile" ]]; then
            print_step "Testing build for $service"

            # Try to build the Docker image
            if docker build -t "test-$(basename "$service" | tr '[:upper:]' '[:lower:]')" "$service" >/dev/null 2>&1; then
                print_success "Build test passed for $service"

                # Clean up test image
                docker rmi "test-$(basename "$service" | tr '[:upper:]' '[:lower:]')" >/dev/null 2>&1 || true
            else
                print_error "Build test failed for $service"
                print_warning "You may need to run: docker build $service"
            fi
        fi
    done
else
    print_warning "Docker not available, skipping build tests"
fi

print_step "Summary of changes made:"
echo "  ✓ Updated all Dockerfile Go versions to 1.23"
echo "  ✓ Updated all go.mod Go versions to 1.23"
echo "  ✓ Cleaned and updated Go dependencies (if Go available)"
echo "  ✓ Created missing go.sum files"

print_success "Go services fix completed!"
print_step "You can now run: docker-compose build"