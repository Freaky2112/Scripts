#!/usr/bin/env bash
# Script Name: gemini_menu.sh
# Description: A menu to run Gemini-related scripts.
# Author: Gemini CLI
# Date: 2026-01-17
# Usage: ./gemini_menu.sh

set -euo pipefail

# Script paths
GEMINI_WRAPPER_SCRIPT="$HOME/.local/bin/gemini-wrapper.sh"
REINSTALL_GEMINI_SCRIPT="$HOME/.local/bin/reinstall_gemini_cli.sh"
CHATGPT_DIR="$HOME/chatgpt"

# Colors for better readability
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly YELLOW='\e[38;5;220m'
readonly GRAY='\e[38;5;246m'

# Default Linux system directories
readonly DEFAULT_DIRS=(
    "/"
    "/bin"
    "/boot"
    "/dev"
    "/etc"
    "/home"
    "/lib"
    "/lib64"
    "/media"
    "/mnt"
    "/opt"
    "/proc"
    "/root"
    "/run"
    "/sbin"
    "/srv"
    "/sys"
    "/tmp"
    "/usr"
    "/var"
)

function is_system_directory() {
    local current_dir
    current_dir="$(pwd)"
    
    # Check if in system directories
    for dir in "${DEFAULT_DIRS[@]}"; do
        if [[ "$current_dir" == "$dir" ]] || [[ "$current_dir" == "$dir"/* ]]; then
            return 0  # True - is in a system directory
        fi
    done
    
    return 1  # False - not in a system directory
}

function is_hidden_home_directory() {
    local current_dir
    current_dir="$(pwd)"
    
    # Check if we're in $HOME or a subdirectory of $HOME
    if [[ "$current_dir" == "$HOME" ]]; then
        return 0  # True - we're in $HOME itself
    fi
    
    # Check if we're in a hidden directory under $HOME (starts with .)
    # Extract the path relative to $HOME
    if [[ "$current_dir" == "$HOME"/* ]]; then
        local relative_path="${current_dir#$HOME/}"
        local first_component="${relative_path%%/*}"
        
        # Check if the first component starts with a dot
        if [[ "$first_component" == .* ]]; then
            return 0  # True - in a hidden directory like ~/.local or ~/.bin
        fi
    fi
    
    return 1  # False - in a regular non-hidden directory under $HOME
}

function should_change_directory() {
    # Change directory if:
    # 1. We're in a system directory, OR
    # 2. We're in $HOME itself, OR
    # 3. We're in a hidden directory under $HOME (like ~/.local, ~/.bin)
    
    if is_system_directory; then
        return 0  # True - change directory
    fi
    
    if is_hidden_home_directory; then
        return 0  # True - change directory
    fi
    
    return 1  # False - stay in current directory
}

function setup_working_directory() {
    local current_dir
    current_dir="$(pwd)"
    
    if should_change_directory; then
        echo -e "${YELLOW}Current directory: $current_dir${NC}"
        
        if is_system_directory; then
            echo -e "${YELLOW}This is a system directory.${NC}"
        elif [[ "$current_dir" == "$HOME" ]]; then
            echo -e "${YELLOW}Currently in HOME directory.${NC}"
        else
            echo -e "${YELLOW}Currently in a hidden directory under HOME.${NC}"
        fi
        
        if [[ ! -d "$CHATGPT_DIR" ]]; then
            echo -e "${CYAN}Creating directory: $CHATGPT_DIR${NC}"
            mkdir -p "$CHATGPT_DIR" || {
                echo -e "${RED}Error: Failed to create directory $CHATGPT_DIR${NC}"
                return 1
            }
            echo -e "${GREEN}Directory created successfully.${NC}"
        else
            echo -e "${GREEN}Directory $CHATGPT_DIR already exists.${NC}"
        fi
        
        echo -e "${CYAN}Changing to directory: $CHATGPT_DIR${NC}"
        cd "$CHATGPT_DIR" || {
            echo -e "${RED}Error: Failed to change to directory $CHATGPT_DIR${NC}"
            return 1
        }
        echo -e "${GREEN}Working directory: $(pwd)${NC}"
        sleep 1
    else
        echo -e "${GREEN}Current directory: $current_dir${NC}"
        echo -e "${CYAN}This is a valid working directory (non-hidden folder under HOME).${NC}"
        echo -e "${CYAN}Staying in current directory.${NC}"
        sleep 1
    fi
}

function check_prerequisites() {
    local missing=0
    
    echo -e "${CYAN}Checking prerequisites...${NC}"
    
    if [[ ! -f "$GEMINI_WRAPPER_SCRIPT" ]]; then
        echo -e "${RED}✗ Gemini wrapper script not found at $GEMINI_WRAPPER_SCRIPT${NC}"
        ((missing++))
    else
        if [[ ! -x "$GEMINI_WRAPPER_SCRIPT" ]]; then
            echo -e "${YELLOW}⚠ Gemini wrapper script exists but is not executable${NC}"
            echo -e "${CYAN}Attempting to make it executable...${NC}"
            chmod +x "$GEMINI_WRAPPER_SCRIPT" 2>/dev/null || {
                echo -e "${RED}Failed to make script executable${NC}"
                ((missing++))
            }
        else
            echo -e "${GREEN}✓ Gemini wrapper script found${NC}"
        fi
    fi
    
    if [[ ! -f "$REINSTALL_GEMINI_SCRIPT" ]]; then
        echo -e "${YELLOW}⚠ Reinstall script not found at $REINSTALL_GEMINI_SCRIPT${NC}"
    else
        if [[ ! -x "$REINSTALL_GEMINI_SCRIPT" ]]; then
            chmod +x "$REINSTALL_GEMINI_SCRIPT" 2>/dev/null
        fi
        echo -e "${GREEN}✓ Reinstall script found${NC}"
    fi
    
    if ((missing > 0)); then
        echo -e "${RED}Critical scripts are missing. Please check your installation.${NC}"
        echo "Press any key to continue anyway..."
        read -n 1 -s
    fi
    
    sleep 1
}

function display_menu() {
    clear
    echo -e "${BLUE}╔═════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${GREEN}       Gemini CLI Script Menu          ${BLUE}║${NC}"
    echo -e "${BLUE}╚═════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Working Directory:${NC} $(pwd)"
    echo ""
    
    if [[ -f "$GEMINI_WRAPPER_SCRIPT" && -x "$GEMINI_WRAPPER_SCRIPT" ]]; then
        echo -e "  ${GREEN}1.${NC} Run Gemini CLI"
    else
        echo -e "  ${GRAY}1. Run Gemini CLI (unavailable)${NC}"
    fi
    
    if [[ -f "$REINSTALL_GEMINI_SCRIPT" && -x "$REINSTALL_GEMINI_SCRIPT" ]]; then
        echo -e "  ${YELLOW}2.${NC} Update Gemini CLI"
    else
        echo -e "  ${GRAY}2. Update Gemini CLI (unavailable)${NC}"
    fi
    
    echo -e "  ${RED}3.${NC} Exit"
    echo ""
    echo -e "${BLUE}─────────────────────────────────────────${NC}"
    echo -n -e "${GREEN}Enter your choice [1-3]:${NC} "
}

function run_script() {
    local script_path="$1"
    local script_name="$2"
    
    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}✗ Error: Script not found at $script_path${NC}"
        echo "Press any key to continue..."
        read -n 1 -s
        return 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        echo -e "${RED}✗ Error: Script is not executable at $script_path${NC}"
        echo "Press any key to continue..."
        read -n 1 -s
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}▶ Running $script_name...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    # Execute the script
    "$script_path" || {
        echo ""
        echo -e "${RED}✗ Script encountered an error.${NC}"
        echo "Press any key to continue..."
        read -n 1 -s
        return 1
    }
    
    echo ""
    echo -e "${GREEN}✓ Script finished successfully.${NC}"
    echo "Press any key to continue..."
    read -n 1 -s
}

function main() {
    # Setup working directory first
    setup_working_directory || {
        echo -e "${RED}Failed to setup working directory. Exiting.${NC}"
        exit 1
    }
    
    # Check prerequisites
    check_prerequisites
    
    # Main menu loop
    while true; do
        display_menu
        read -r choice
        
        case "$choice" in
            1)
                if [[ -f "$GEMINI_WRAPPER_SCRIPT" && -x "$GEMINI_WRAPPER_SCRIPT" ]]; then
                    run_script "$GEMINI_WRAPPER_SCRIPT" "Gemini CLI"
                else
                    echo -e "${RED}✗ Gemini CLI is not available.${NC}"
                    echo "Press any key to continue..."
                    read -n 1 -s
                fi
                ;;
            2)
                if [[ -f "$REINSTALL_GEMINI_SCRIPT" && -x "$REINSTALL_GEMINI_SCRIPT" ]]; then
                    run_script "$REINSTALL_GEMINI_SCRIPT" "Gemini CLI Update"
                else
                    echo -e "${RED}✗ Update script is not available.${NC}"
                    echo "Press any key to continue..."
                    read -n 1 -s
                fi
                ;;
            3)
                echo ""
                echo -e "${GREEN}✓ Exiting menu. Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo ""
                echo -e "${RED}✗ Invalid choice. Please enter 1-3.${NC}"
                echo "Press any key to try again..."
                read -n 1 -s
                ;;
        esac
    done
}

# Trap for clean exit
trap 'echo -e "\n${CYAN}Cleaning up...${NC}"' EXIT

# Execute main function
main "$@"