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

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Error handling function
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit "${2:-1}"
}

# Warning function
warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
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
    echo -e "${BLUE}Verifying Gemini CLI Wrapper Setup...${NC}"
    echo "=========================================="
    
    # Check Gemini CLI
    if command -v "$GEMINI_CMD" &> /dev/null; then
        echo -e "${GREEN}✓${NC} Gemini CLI found: $(which $GEMINI_CMD)"
    else
        echo -e "${RED}✗${NC} Gemini CLI not found: $GEMINI_CMD"
        exit 1
    fi
    
    # Check logging tools
    if command -v script &> /dev/null; then
        echo -e "${GREEN}✓${NC} 'script' command available"
    elif command -v tee &> /dev/null; then
        echo -e "${YELLOW}!${NC} 'script' not found, will use 'tee' (limited functionality)"
    else
        echo -e "${RED}✗${NC} No logging tools available"
        exit 1
    fi
    
    # Check log directory
    if [ -d "$LOG_DIR" ]; then
        if [ -w "$LOG_DIR" ]; then
            echo -e "${GREEN}✓${NC} Log directory exists and is writable: $LOG_DIR"
        else
            echo -e "${RED}✗${NC} Log directory not writable: $LOG_DIR"
            exit 1
        fi
    else
        echo -e "${YELLOW}!${NC} Log directory will be created: $LOG_DIR"
    fi
    
    # Check disk space (warn if less than 100MB)
    if command -v df &> /dev/null; then
        available_space=$(df -k "$(dirname "$LOG_DIR")" | awk 'NR==2 {print $4}')
        if [ "$available_space" -lt 102400 ]; then
            warning "Low disk space: less than 100MB available"
        else
            echo -e "${GREEN}✓${NC} Sufficient disk space available"
        fi
    fi
    
    echo "=========================================="
    echo -e "${GREEN}Verification complete!${NC}"
    exit 0
}

# Function to list all conversations
list_conversations() {
    echo -e "${BLUE}Saved Conversations:${NC}"
    echo "===================="
    
    if [ ! -d "$LOG_DIR" ]; then
        echo "No log directory found at: $LOG_DIR"
        exit 0
    fi
    
    if [ -z "$(ls -A "$LOG_DIR"/chat_*.txt 2>/dev/null)" ]; then
        echo "No conversations found in: $LOG_DIR"
        exit 0
    fi
    
    # List with error handling
    if ! ls -lh "$LOG_DIR"/chat_*.txt 2>/dev/null | awk '{print $9, "(" $5 ")"}'; then
        warning "Error listing conversation files"
    fi
    
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

    echo -e "${YELLOW}Generating summary...${NC}"

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

    echo -e "${GREEN}Summary saved to: $summary_file${NC}"
    echo ""
    echo -e "${BLUE}=== SUMMARY ===${NC}"
    
    if ! cat "$summary_file"; then
        warning "Could not display summary file"
    fi
}

# Function to start interactive session
start_session() {
    echo -e "${GREEN}Starting Gemini CLI session with logging...${NC}"
    echo -e "Chat log: ${BLUE}$CHAT_LOG${NC}"
    echo -e "Summary will be saved to: ${BLUE}$SUMMARY_LOG${NC}"
    echo ""
    echo "=========================================="
    echo ""

    # Create header for chat log
    {
        echo "=== Gemini Chat Session ==="
        echo "Date: $(date)"
        echo "========================================"
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
    echo "=========================================="
    
    if [ $session_exit_code -ne 0 ]; then
        warning "Gemini session exited with code: $session_exit_code"
    fi
    
    echo -e "${GREEN}Session ended. Chat saved.${NC}"
    
    # Verify log file was created and has content
    if [ ! -s "$CHAT_LOG" ]; then
        warning "Chat log file is empty or was not created properly"
        return 1
    fi
    
    echo ""

    # Ask if user wants to generate summary
    read -p "Generate summary? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        generate_summary "$CHAT_LOG" "$SUMMARY_LOG" || warning "Summary generation failed"
    else
        echo "You can generate a summary later with: $0 --summarize $CHAT_LOG"
    fi
}

# Trap errors and cleanup
trap 'echo -e "${RED}Script interrupted${NC}"; exit 130' INT TERM

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