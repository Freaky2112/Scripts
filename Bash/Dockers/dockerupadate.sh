#!/bin/bash

# Docker Update Checker Script
# This script checks Docker, Docker Compose, images, and containers for updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ask user for confirmation
ask_update() {
    local prompt="$1"
    echo -e "${YELLOW}${prompt} (y/n): ${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check Docker installation
check_docker() {
    print_header "Checking Docker"
    
    if ! command_exists docker; then
        print_error "Docker is not installed"
        if ask_update "Would you like to install Docker?"; then
            print_info "Please visit: https://docs.docker.com/get-docker/"
        fi
        return 1
    fi
    
    local current_version=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
    print_info "Current Docker version: $current_version"
    
    # Fetch latest version from Docker GitHub releases
    print_info "Checking for latest Docker version..."
    local latest_version=$(curl -s https://api.github.com/repos/moby/moby/releases/latest | grep -oP '"tag_name": "v\K[^"]+' 2>/dev/null || echo "unknown")
    
    if [ "$latest_version" != "unknown" ]; then
        print_info "Latest Docker version: $latest_version"
        
        if [ "$current_version" != "$latest_version" ]; then
            print_warning "A newer version of Docker is available!"
            if ask_update "Would you like to update Docker?"; then
                update_docker
            fi
        else
            print_success "Docker is up to date"
        fi
    else
        print_warning "Could not fetch latest Docker version"
    fi
}

# Check Docker Compose
check_docker_compose() {
    print_header "Checking Docker Compose"
    
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not installed"
        if ask_update "Would you like to install Docker Compose?"; then
            print_info "Please visit: https://docs.docker.com/compose/install/"
        fi
        return 1
    fi
    
    # Check for both standalone and plugin versions
    if docker compose version >/dev/null 2>&1; then
        local current_version=$(docker compose version --short 2>/dev/null || docker compose version | grep -oP '\d+\.\d+\.\d+' | head -1)
        print_info "Current Docker Compose (plugin) version: $current_version"
    elif command_exists docker-compose; then
        local current_version=$(docker-compose --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        print_info "Current Docker Compose (standalone) version: $current_version"
        print_warning "You're using standalone Docker Compose. Consider migrating to Docker Compose V2 (plugin)"
    fi
    
    print_success "Docker Compose is installed"
}

# Update Docker (Linux)
update_docker() {
    print_info "Updating Docker..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io
            print_success "Docker updated successfully"
        elif command_exists yum; then
            sudo yum update -y docker-ce docker-ce-cli containerd.io
            print_success "Docker updated successfully"
        else
            print_error "Unable to auto-update. Please update manually."
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "On macOS, please update Docker Desktop through the application or download from:"
        print_info "https://www.docker.com/products/docker-desktop"
    else
        print_info "Please update Docker manually for your operating system"
    fi
}

# Check Docker images for updates
check_images() {
    print_header "Checking Docker Images"
    
    if [ -z "$(docker images -q)" ]; then
        print_info "No Docker images found"
        return 0
    fi
    
    print_info "Checking for image updates..."
    local images_to_update=()
    
    # Get list of images
    while IFS= read -r line; do
        local repo=$(echo "$line" | awk '{print $1}')
        local tag=$(echo "$line" | awk '{print $2}')
        local image_id=$(echo "$line" | awk '{print $3}')
        
        # Skip <none> images
        if [ "$repo" = "<none>" ]; then
            continue
        fi
        
        echo -e "\nChecking: ${repo}:${tag}"
        
        # Pull latest digest info
        if docker pull "$repo:$tag" >/dev/null 2>&1; then
            local new_image_id=$(docker images -q "$repo:$tag" | head -1)
            
            if [ "$image_id" != "$new_image_id" ]; then
                print_warning "Update available for $repo:$tag"
                images_to_update+=("$repo:$tag")
            else
                print_success "$repo:$tag is up to date"
            fi
        else
            print_warning "Could not check $repo:$tag (might be a local image)"
        fi
    done < <(docker images --format "{{.Repository}} {{.Tag}} {{.ID}}" | grep -v "<none>")
    
    if [ ${#images_to_update[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Images with updates available:${NC}"
        printf '%s\n' "${images_to_update[@]}"
    fi
}

# Check running containers
check_containers() {
    print_header "Checking Running Containers"
    
    if [ -z "$(docker ps -q)" ]; then
        print_info "No running containers"
        return 0
    fi
    
    print_info "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    if ask_update "Would you like to restart containers to use updated images?"; then
        restart_containers
    fi
}

# Restart containers
restart_containers() {
    print_info "Restarting containers..."
    
    if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
        print_info "Found docker-compose file. Using docker compose..."
        docker compose down
        docker compose up -d
        print_success "Containers restarted with docker compose"
    else
        print_warning "No docker-compose file found. Restarting individual containers..."
        for container in $(docker ps -q); do
            local name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
            docker restart "$container"
            print_success "Restarted: $name"
        done
    fi
}

# Clean up unused resources
cleanup_docker() {
    print_header "Docker Cleanup"
    
    print_info "Current disk usage:"
    docker system df
    
    echo ""
    if ask_update "Would you like to clean up unused Docker resources?"; then
        print_info "Cleaning up..."
        
        # Remove stopped containers
        print_info "Removing stopped containers..."
        docker container prune -f
        
        # Remove dangling images
        print_info "Removing dangling images..."
        docker image prune -f
        
        # Remove unused volumes
        if ask_update "Remove unused volumes? (This may delete data)"; then
            docker volume prune -f
        fi
        
        # Remove unused networks
        print_info "Removing unused networks..."
        docker network prune -f
        
        print_success "Cleanup complete!"
        echo ""
        print_info "New disk usage:"
        docker system df
    fi
}

# Check Docker daemon status
check_daemon() {
    print_header "Checking Docker Daemon"
    
    if docker info >/dev/null 2>&1; then
        print_success "Docker daemon is running"
        
        # Show some daemon info
        print_info "Docker Info:"
        docker info --format "Server Version: {{.ServerVersion}}"
        docker info --format "Storage Driver: {{.Driver}}"
        docker info --format "Containers: {{.Containers}} ({{.ContainersRunning}} running)"
        docker info --format "Images: {{.Images}}"
    else
        print_error "Docker daemon is not running"
        if ask_update "Would you like to start Docker daemon?"; then
            sudo systemctl start docker 2>/dev/null || print_error "Failed to start Docker daemon"
        fi
    fi
}

# Main execution
main() {
    print_header "Docker Update Checker"
    print_info "Starting comprehensive Docker check..."
    
    check_daemon
    check_docker
    check_docker_compose
    check_images
    check_containers
    cleanup_docker
    
    print_header "Check Complete"
    print_success "All checks finished!"
    print_info "Run this script regularly to keep your Docker environment up to date."
}

# Run main function
main