#!/bin/bash

# Gemini CLI Wrapper with Chat Logging and Summary
# This script wraps the Gemini CLI to capture conversations and generate summaries

# Strict error handling
set -o pipefail

# Configuration
GEMINI_CMD="gemini"  # Change this to your actual Gemini CLI command
# Default to current directory, or use custom path
LOG_DIR="${GEMINI_LOG_DIR:-$(pwd)/gemini_logs}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CHAT_LOG="$LOG_DIR/chat_$TIMESTAMP.txt"
SUMMARY_LOG="$LOG_DIR/summary_$TIMESTAMP.txt"

# Colors and styles for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
REVERSE='\033[7m'
NC='\033[0m' # No Color

# Fun ASCII art and decorations
ROBOT="🤖"
SPARKLE="✨"
ROCKET="🚀"
FIRE="🔥"
CHECK="✓"
CROSS="✗"
WARN="⚠"
STAR="★"
ARROW="→"

# Error handling function
error_exit() {
    echo ""
    echo -e "${RED}${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║  ${CROSS} ERROR: $1"
    echo -e "${RED}${BOLD}╚════════════════════════════════════════╝${NC}"
    echo ""
    exit "${2:-1}"
}

# Warning function
warning() {
    echo -e "${YELLOW}${BOLD}${WARN} WARNING:${NC} ${YELLOW}$1${NC}" >&2
}

# Success message function
success() {
    echo -e "${GREEN}${BOLD}${CHECK} $1${NC}"
}

# Info message function
info() {
    echo -e "${CYAN}${ARROW}${NC} $1"
}

# Banner function
print_banner() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║        ${ROBOT}  GEMINI CLI WRAPPER ${SPARKLE}                         ║"
    echo "║                                                          ║"
    echo "║     ${FIRE} Chat Logging + AI Summaries ${FIRE}                    ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check dependencies
check_dependencies() {
    # Check if Gemini CLI is available
    if ! command -v "$GEMINI_CMD" &> /dev/null; then
        error_exit "Gemini CLI command '$GEMINI_CMD' not found. Please install it or update GEMINI_CMD variable." 2
    fi

    # Check if we have script or tee for logging
    if ! command -v script &> /dev/null && ! command -v tee &> /dev/null; then
        error_exit "Neither 'script' nor 'tee' command found. Cannot log sessions." 3
    fi

    # Check write permissions for log directory
    if [ -d "$LOG_DIR" ] && [ ! -w "$LOG_DIR" ]; then
        error_exit "Log directory '$LOG_DIR' exists but is not writable. Check permissions." 4
    fi
}

# Create log directory with error checking
create_log_dir() {
    if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
        error_exit "Failed to create log directory: $LOG_DIR" 5
    fi
    
    # Verify directory was created and is writable
    if [ ! -d "$LOG_DIR" ]; then
        error_exit "Log directory does not exist after creation attempt: $LOG_DIR" 6
    fi
    
    if [ ! -w "$LOG_DIR" ]; then
        error_exit "Log directory is not writable: $LOG_DIR" 7
    fi
}

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -l, --list           List all saved conversations"
    echo "  -s, --summarize FILE Summarize an existing chat log"
    echo "  -d, --dir PATH       Set custom log directory (default: ./gemini_logs)"
    echo "  -v, --verify         Verify dependencies and configuration"
    echo ""
    echo "Without options, starts an interactive Gemini session with logging"
    echo ""
    echo "Environment Variables:"
    echo "  GEMINI_LOG_DIR       Set default log directory for all sessions"
    echo "  GEMINI_CMD           Set custom Gemini CLI command (default: gemini)"
    echo ""
    echo "Default behavior: Saves logs to 'gemini_logs' folder in current directory"
    exit 0
}

# Function to verify setup
verify_setup() {
    print_banner
    echo -e "${CYAN}${BOLD}${ROCKET} Verifying Gemini CLI Wrapper Setup...${NC}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Check Gemini CLI
    if command -v "$GEMINI_CMD" &> /dev/null; then
        success "Gemini CLI found: ${BOLD}$(which $GEMINI_CMD)${NC}"
    else
        echo -e "${RED}${CROSS}${NC} Gemini CLI not found: ${BOLD}$GEMINI_CMD${NC}"
        exit 1
    fi
    
    # Check logging tools
    if command -v script &> /dev/null; then
        success "'script' command available"
    elif command -v tee &> /dev/null; then
        echo -e "${YELLOW}${WARN}${NC} 'script' not found, will use 'tee' (limited functionality)"
    else
        echo -e "${RED}${CROSS}${NC} No logging tools available"
        exit 1
    fi
    
    # Check log directory
    if [ -d "$LOG_DIR" ]; then
        if [ -w "$LOG_DIR" ]; then
            success "Log directory exists and is writable: ${BOLD}$LOG_DIR${NC}"
        else
            echo -e "${RED}${CROSS}${NC} Log directory not writable: ${BOLD}$LOG_DIR${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}${WARN}${NC} Log directory will be created: ${BOLD}$LOG_DIR${NC}"
    fi
    
    # Check disk space (warn if less than 100MB)
    if command -v df &> /dev/null; then
        available_space=$(df -k "$(dirname "$LOG_DIR")" | awk 'NR==2 {print $4}')
        if [ "$available_space" -lt 102400 ]; then
            warning "Low disk space: less than 100MB available"
        else
            success "Sufficient disk space available"
        fi
    fi
    
    echo ""
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}${SPARKLE} Verification complete! Ready to rock! ${SPARKLE}${NC}"
    echo ""
    exit 0
}

# Function to list all conversations
list_conversations() {
    print_banner
    echo -e "${CYAN}${BOLD}📚 Saved Conversations Archive${NC}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ ! -d "$LOG_DIR" ]; then
        echo -e "${YELLOW}  No log directory found at: ${BOLD}$LOG_DIR${NC}"
        echo ""
        exit 0
    fi
    
    if [ -z "$(ls -A "$LOG_DIR"/chat_*.txt 2>/dev/null)" ]; then
        echo -e "${YELLOW}  No conversations found in: ${BOLD}$LOG_DIR${NC}"
        echo -e "${DIM}  (Start a session to create your first chat log!)${NC}"
        echo ""
        exit 0
    fi
    
    # List with error handling and fancy formatting
    if ! ls -lh "$LOG_DIR"/chat_*.txt 2>/dev/null | awk -v green="$GREEN" -v bold="$BOLD" -v nc="$NC" -v cyan="$CYAN" '{print "  " cyan "▸" nc " " bold $9 nc " " green "(" $5 ")" nc}'; then
        warning "Error listing conversation files"
    fi
    
    echo ""
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
}

# Function to generate summary using Gemini
generate_summary() {
    local chat_file="$1"
    local summary_file="$2"

    # Validate input file
    if [ ! -f "$chat_file" ]; then
        error_exit "Chat file not found: $chat_file" 10
    fi
    
    if [ ! -r "$chat_file" ]; then
        error_exit "Chat file not readable: $chat_file" 11
    fi
    
    # Check if file is empty
    if [ ! -s "$chat_file" ]; then
        error_exit "Chat file is empty: $chat_file" 12
    fi

    echo ""
    echo -e "${MAGENTA}${BOLD}${SPARKLE} Generating AI-Powered Summary... ${SPARKLE}${NC}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Create a prompt for summarization
    local prompt="Please provide a concise summary of the following conversation. Include:
1. Main topics discussed
2. Key questions asked
3. Important answers or solutions provided
4. Action items or conclusions

Conversation:
$(cat "$chat_file")

Please format the summary in a clear, organized manner."

    # Send to Gemini for summarization with error handling
    if ! echo "$prompt" | $GEMINI_CMD > "$summary_file" 2>&1; then
        error_exit "Failed to generate summary. Check Gemini CLI configuration and network connection." 13
    fi
    
    # Verify summary was created
    if [ ! -f "$summary_file" ] || [ ! -s "$summary_file" ]; then
        error_exit "Summary file was not created or is empty: $summary_file" 14
    fi

    success "Summary saved to: ${BOLD}$summary_file${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                    📋 SUMMARY                             ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if ! cat "$summary_file"; then
        warning "Could not display summary file"
    fi
    echo ""
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to start interactive session
start_session() {
    print_banner
    echo -e "${GREEN}${BOLD}${ROCKET} Starting Gemini CLI Session ${ROCKET}${NC}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    info "Chat log: ${BOLD}${BLUE}$CHAT_LOG${NC}"
    info "Summary: ${BOLD}${MAGENTA}$SUMMARY_LOG${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}  ┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}${BOLD}  │  💬 Your conversation is being logged...        │${NC}"
    echo -e "${YELLOW}${BOLD}  └─────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Create header for chat log
    {
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║           GEMINI CHAT SESSION LOG                      ║"
        echo "╚════════════════════════════════════════════════════════╝"
        echo ""
        echo "Date: $(date)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    } > "$CHAT_LOG" || error_exit "Failed to create chat log file: $CHAT_LOG" 15

    # Use script command to capture the entire session
    local session_exit_code=0
    
    if command -v script &> /dev/null; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS version
            script -q "$CHAT_LOG" $GEMINI_CMD || session_exit_code=$?
        else
            # Linux version
            script -q -c "$GEMINI_CMD" "$CHAT_LOG" || session_exit_code=$?
        fi
    else
        # Fallback: direct execution with tee
        warning "'script' command not available, using 'tee' (limited capture)"
        $GEMINI_CMD 2>&1 | tee -a "$CHAT_LOG" || session_exit_code=$?
    fi

    echo ""
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ $session_exit_code -ne 0 ]; then
        warning "Gemini session exited with code: $session_exit_code"
    fi
    
    success "Session ended. Chat saved!"
    
    # Verify log file was created and has content
    if [ ! -s "$CHAT_LOG" ]; then
        warning "Chat log file is empty or was not created properly"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}${BOLD}  📝 Generate an AI summary of this conversation?${NC}"
    read -p "  $(echo -e ${GREEN}[Y]${NC}es / ${RED}[N]${NC}o): " -n 1 -r
    echo
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        generate_summary "$CHAT_LOG" "$SUMMARY_LOG" || warning "Summary generation failed"
    else
        info "No problem! Generate it later with:"
        echo -e "  ${BOLD}${CYAN}$0 --summarize $CHAT_LOG${NC}"
        echo ""
    fi
}

# Trap errors and cleanup
trap 'echo ""; echo -e "${RED}${BOLD}⚡ Script interrupted! Cleaning up...${NC}"; exit 130' INT TERM

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -v|--verify)
            check_dependencies
            create_log_dir
            verify_setup
            ;;
        -l|--list)
            list_conversations
            ;;
        -s|--summarize)
            if [ -z "$2" ]; then
                error_exit "Option --summarize requires a file argument" 20
            fi
            CHAT_FILE="$2"
            if [ ! -f "$CHAT_FILE" ]; then
                error_exit "File not found: $CHAT_FILE" 21
            fi
            check_dependencies
            SUMMARY_FILE="${CHAT_FILE%.txt}_summary.txt"
            generate_summary "$CHAT_FILE" "$SUMMARY_FILE"
            exit 0
            ;;
        -d|--dir)
            if [ -z "$2" ]; then
                error_exit "Option --dir requires a path argument" 22
            fi
            LOG_DIR="$2"
            CHAT_LOG="$LOG_DIR/chat_$TIMESTAMP.txt"
            SUMMARY_LOG="$LOG_DIR/summary_$TIMESTAMP.txt"
            shift 2
            ;;
        *)
            error_exit "Unknown option: $1\nUse --help for usage information" 23
            ;;
    esac
done

# Main execution
check_dependencies
create_log_dir
start_session