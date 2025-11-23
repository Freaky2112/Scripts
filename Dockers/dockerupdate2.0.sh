#!/bin/bash

# Docker Update Checker Script with Whiptail Menu
# This script checks Docker, Docker Compose, images, and containers for updates

set -e

# Colors for output (when not using whiptail)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Temp file for whiptail results
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Helper functions
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

# Check if whiptail is installed
check_whiptail() {
    if ! command -v whiptail >/dev/null 2>&1; then
        echo "Whiptail is not installed. Installing..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y whiptail
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y newt
        else
            echo "Please install whiptail manually"
            exit 1
        fi
    fi
}

# Show message box
show_message() {
    whiptail --title "$1" --msgbox "$2" 15 60
}

# Show info box
show_info() {
    whiptail --title "$1" --infobox "$2" 10 60
    sleep 2
}

# Ask yes/no question
ask_yesno() {
    whiptail --title "$1" --yesno "$2" 10 60
}

# Show progress
show_progress() {
    local title="$1"
    local message="$2"
    echo "$message" | whiptail --title "$title" --gauge "Please wait..." 10 60 0
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Docker installation
check_docker() {
    clear
    print_info "Checking Docker installation..."
    
    if ! command_exists docker; then
        show_message "Docker Not Found" "Docker is not installed on this system.\n\nWould you like installation instructions?"
        if ask_yesno "Install Docker?" "Open browser to Docker installation page?"; then
            print_info "Please visit: https://docs.docker.com/get-docker/"
        fi
        return 1
    fi
    
    local current_version=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
    local latest_version=$(curl -s https://api.github.com/repos/moby/moby/releases/latest | grep -oP '"tag_name": "v\K[^"]+' 2>/dev/null || echo "unknown")
    
    local message="Current Version: $current_version\n"
    if [ "$latest_version" != "unknown" ]; then
        message+="Latest Version: $latest_version\n\n"
        if [ "$current_version" != "$latest_version" ]; then
            message+="⚠ Update Available!"
            if whiptail --title "Docker Update Available" --yesno "$message\n\nWould you like to update Docker?" 15 60; then
                update_docker
            fi
        else
            message+="✓ Docker is up to date!"
            show_message "Docker Status" "$message"
        fi
    else
        message+="Could not fetch latest version"
        show_message "Docker Status" "$message"
    fi
    
    print_success "Docker check complete"
}

# Check Docker Compose
check_docker_compose() {
    clear
    print_info "Checking Docker Compose..."
    
    local message=""
    
    if docker compose version >/dev/null 2>&1; then
        local current_version=$(docker compose version --short 2>/dev/null || docker compose version | grep -oP '\d+\.\d+\.\d+' | head -1)
        message="Docker Compose Plugin\nVersion: $current_version\n\n✓ Installed"
        show_message "Docker Compose Status" "$message"
    elif command_exists docker-compose; then
        local current_version=$(docker-compose --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        message="Docker Compose Standalone\nVersion: $current_version\n\n⚠ Consider upgrading to Docker Compose V2 (plugin)"
        show_message "Docker Compose Status" "$message"
    else
        show_message "Docker Compose Not Found" "Docker Compose is not installed.\n\nVisit: https://docs.docker.com/compose/install/"
        return 1
    fi
    
    print_success "Docker Compose check complete"
}

# Update Docker
update_docker() {
    clear
    print_info "Updating Docker..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt-get; then
            (
                echo "10" ; sleep 1
                echo "30" ; sudo apt-get update 2>&1 | tail -1
                echo "60" ; sudo apt-get install -y docker-ce docker-ce-cli containerd.io 2>&1 | tail -1
                echo "100" ; sleep 1
            ) | whiptail --title "Updating Docker" --gauge "Installing updates..." 10 60 0
            show_message "Success" "Docker has been updated successfully!"
        elif command_exists yum; then
            sudo yum update -y docker-ce docker-ce-cli containerd.io
            show_message "Success" "Docker has been updated successfully!"
        else
            show_message "Manual Update Required" "Unable to auto-update.\n\nPlease update Docker manually for your system."
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        show_message "macOS Update" "On macOS, please update Docker Desktop through:\n\n1. Docker Desktop application\n2. Or download from:\n   https://www.docker.com/products/docker-desktop"
    else
        show_message "Manual Update Required" "Please update Docker manually for your operating system."
    fi
}

# Check Docker images
check_images() {
    clear
    print_info "Checking Docker images for updates..."
    
    if [ -z "$(docker images -q)" ]; then
        show_message "No Images" "No Docker images found on this system."
        return 0
    fi
    
    local output=""
    local update_count=0
    
    # Show progress while checking
    {
        local total=$(docker images | wc -l)
        local current=0
        
        while IFS= read -r line; do
            local repo=$(echo "$line" | awk '{print $1}')
            local tag=$(echo "$line" | awk '{print $2}')
            local image_id=$(echo "$line" | awk '{print $3}')
            
            if [ "$repo" = "<none>" ]; then
                continue
            fi
            
            current=$((current + 1))
            local percent=$((current * 100 / total))
            echo "$percent"
            echo "XXX"
            echo "Checking: $repo:$tag"
            echo "XXX"
            
            if docker pull "$repo:$tag" >/dev/null 2>&1; then
                local new_image_id=$(docker images -q "$repo:$tag" | head -1)
                
                if [ "$image_id" != "$new_image_id" ]; then
                    output+="⚠ UPDATE: $repo:$tag\n"
                    update_count=$((update_count + 1))
                else
                    output+="✓ Current: $repo:$tag\n"
                fi
            else
                output+="⚠ Cannot check: $repo:$tag (local image?)\n"
            fi
            
        done < <(docker images --format "{{.Repository}} {{.Tag}} {{.ID}}" | grep -v "<none>")
    } | whiptail --title "Checking Images" --gauge "Scanning images..." 10 60 0
    
    # Show results
    if [ $update_count -gt 0 ]; then
        output+="\nFound $update_count image(s) with updates available."
    else
        output+="\nAll images are up to date!"
    fi
    
    whiptail --title "Image Check Results" --msgbox "$output" 20 70
    print_success "Image check complete"
}

# Check running containers
check_containers() {
    clear
    print_info "Checking running containers..."
    
    if [ -z "$(docker ps -q)" ]; then
        show_message "No Containers" "No containers are currently running."
        return 0
    fi
    
    local output=$(docker ps --format "{{.Names}}\t{{.Image}}\t{{.Status}}" | column -t)
    
    if whiptail --title "Running Containers" --yesno "$output\n\nWould you like to restart containers?" 20 70; then
        restart_containers
    fi
}

# Restart containers
restart_containers() {
    clear
    print_info "Restarting containers..."
    
    if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
        (
            echo "25" ; docker compose down 2>&1 | tail -1
            echo "50" ; sleep 1
            echo "75" ; docker compose up -d 2>&1 | tail -1
            echo "100" ; sleep 1
        ) | whiptail --title "Restarting Services" --gauge "Using docker compose..." 10 60 0
        show_message "Success" "Containers restarted with docker compose!"
    else
        local total=$(docker ps -q | wc -l)
        local current=0
        
        for container in $(docker ps -q); do
            current=$((current + 1))
            local percent=$((current * 100 / total))
            local name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
            echo "$percent"
            echo "XXX"
            echo "Restarting: $name"
            echo "XXX"
            docker restart "$container" >/dev/null 2>&1
        done | whiptail --title "Restarting Containers" --gauge "Please wait..." 10 60 0
        
        show_message "Success" "All containers have been restarted!"
    fi
    
    print_success "Containers restarted"
}

# Clean up unused resources
cleanup_docker() {
    clear
    
    local disk_usage=$(docker system df 2>/dev/null || echo "Unable to get disk usage")
    
    if whiptail --title "Docker Cleanup" --yesno "Current disk usage:\n\n$disk_usage\n\nWould you like to clean up unused Docker resources?" 20 70; then
        
        # Create checklist for cleanup options
        local cleanup_options=$(whiptail --title "Select Cleanup Options" --checklist \
            "Choose what to clean up:" 15 60 4 \
            "1" "Stopped containers" ON \
            "2" "Dangling images" ON \
            "3" "Unused volumes" OFF \
            "4" "Unused networks" ON \
            3>&1 1>&2 2>&3)
        
        if [ -n "$cleanup_options" ]; then
            {
                echo "10"
                if echo "$cleanup_options" | grep -q "1"; then
                    echo "XXX"
                    echo "Removing stopped containers..."
                    echo "XXX"
                    docker container prune -f >/dev/null 2>&1
                fi
                
                echo "40"
                if echo "$cleanup_options" | grep -q "2"; then
                    echo "XXX"
                    echo "Removing dangling images..."
                    echo "XXX"
                    docker image prune -f >/dev/null 2>&1
                fi
                
                echo "70"
                if echo "$cleanup_options" | grep -q "3"; then
                    echo "XXX"
                    echo "Removing unused volumes..."
                    echo "XXX"
                    docker volume prune -f >/dev/null 2>&1
                fi
                
                echo "90"
                if echo "$cleanup_options" | grep -q "4"; then
                    echo "XXX"
                    echo "Removing unused networks..."
                    echo "XXX"
                    docker network prune -f >/dev/null 2>&1
                fi
                
                echo "100"
                sleep 1
            } | whiptail --title "Cleaning Up" --gauge "Please wait..." 10 60 0
            
            local new_usage=$(docker system df 2>/dev/null || echo "Unable to get disk usage")
            show_message "Cleanup Complete" "Cleanup finished!\n\nNew disk usage:\n$new_usage"
        fi
    fi
    
    print_success "Cleanup complete"
}

# Check Docker daemon
check_daemon() {
    clear
    print_info "Checking Docker daemon..."
    
    if docker info >/dev/null 2>&1; then
        local info=$(docker info --format "Server Version: {{.ServerVersion}}\nStorage Driver: {{.Driver}}\nContainers: {{.Containers}} ({{.ContainersRunning}} running)\nImages: {{.Images}}")
        show_message "Docker Daemon Status" "✓ Docker daemon is running\n\n$info"
    else
        if ask_yesno "Docker Daemon Stopped" "Docker daemon is not running.\n\nWould you like to start it?"; then
            sudo systemctl start docker 2>/dev/null && \
                show_message "Success" "Docker daemon started successfully!" || \
                show_message "Error" "Failed to start Docker daemon.\n\nPlease start it manually."
        fi
    fi
}

# View system information
view_system_info() {
    clear
    local info=$(docker system info 2>/dev/null | head -30)
    whiptail --title "Docker System Information" --msgbox "$info" 25 80
}

# View all images
view_images() {
    clear
    local images=$(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}")
    whiptail --title "Docker Images" --msgbox "$images" 25 100
}

# View all containers
view_all_containers() {
    clear
    local containers=$(docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}")
    whiptail --title "All Containers" --msgbox "$containers" 25 100
}

# Main menu
show_main_menu() {
    while true; do
        local choice=$(whiptail --title "Docker Update Checker" --menu "Choose an option:" 20 70 12 \
            "1" "Check Docker Daemon Status" \
            "2" "Check Docker Version" \
            "3" "Check Docker Compose" \
            "4" "Check Images for Updates" \
            "5" "Check Running Containers" \
            "6" "View All Images" \
            "7" "View All Containers" \
            "8" "View System Information" \
            "9" "Cleanup Unused Resources" \
            "10" "Run Full Check (All Above)" \
            "11" "Exit" \
            3>&1 1>&2 2>&3)
        
        case $choice in
            1) check_daemon ;;
            2) check_docker ;;
            3) check_docker_compose ;;
            4) check_images ;;
            5) check_containers ;;
            6) view_images ;;
            7) view_all_containers ;;
            8) view_system_info ;;
            9) cleanup_docker ;;
            10) run_full_check ;;
            11) exit 0 ;;
            *) exit 0 ;;
        esac
    done
}

# Run full check
run_full_check() {
    check_daemon
    check_docker
    check_docker_compose
    check_images
    check_containers
    cleanup_docker
    show_message "Complete" "Full system check completed!\n\nAll checks have been performed."
}

# Main execution
main() {
    check_whiptail
    show_main_menu
}

# Run main function
main