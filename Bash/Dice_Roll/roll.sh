#!/bin/bash
#
# dice_roll.sh - Simple D&D dice roller
#
# Usage:
#   ./dice_roll.sh 1d20      # roll one d20
#   ./dice_roll.sh 2d6       # roll two d6
#   ./dice_roll.sh d8        # roll one d8 (count optional)
#
# If no argument is given, you'll be prompted interactively.

BLUE='\e[038:5:27m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
GREEN='\e[038;5;34m'
ORANGE='\e[038;5;214m'
PINK='\e[038;5;213m'
RED='\033[1;31m'
BOLD='\033[1m'
RESET='\033[0m' # No Color


roll_dice() {
    local input="$1"

    # Allow "d20" as shorthand for "1d20"
    if [[ "$input" =~ ^d ]]; then
        input="1$input"
    fi

    # Validate format: NdM (e.g. 2d6, 1d20)
    if [[ ! "$input" =~ ^([0-9]+)d([0-9]+)$ ]]; then
        echo "Error: invalid dice notation '$input'. Use format like 2d6 or d20." >&2
        return 1
    fi

    local count="${BASH_REMATCH[1]}"
    local sides="${BASH_REMATCH[2]}"

    if (( count < 1 || sides < 1 )); then
        echo "Error: dice count and sides must be positive numbers." >&2
        return 1
    fi

    local total=0
    local rolls=()

    for ((i = 0; i < count; i++)); do
        roll=$(( (RANDOM % sides) + 1 ))
        rolls+=("$roll")
        total=$(( total + roll ))
    done

    echo -e "${CYAN}Rolling ${BLUE}${count}d${sides}..."
    echo -e "${YELLOW}Individual rolls: ${ORANGE}${rolls[*]}"
    echo -e "${PINK}${BOLD}Total: ${GREEN}$total${RESET}"
}

# Main
if [[ -n "$1" ]]; then
    roll_dice "$1"
else
    read -rp "Enter dice notation (e.g. 2d6, d20): " user_input
    roll_dice "$user_input"
fi
