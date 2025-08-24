#!/bin/bash
CONFIG_FILE="$HOME/.ssh/config"
LAST_FILE="$HOME/.ssh/.last_ssh_host"

# Extract aliases
HOSTS=$(grep -E '^[[:space:]]*Host[[:space:]]+' "$CONFIG_FILE" \
    | sed -E 's/^[[:space:]]*Host[[:space:]]+//' \
    | grep -v '^\*' \
    | tr -d '\r' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

declare -A HOST_MAP
MENU=()

# Optional "Last connected"
if [[ -f "$LAST_FILE" ]]; then
    LAST=$(cat "$LAST_FILE")
    MENU+=("Last" "Reconnect to $LAST")
fi

# Build the rest of the menu
for alias in $HOSTS; do
    ip=$(awk -v host="$alias" '
        $1=="Host" && $2==host {found=1; next}
        found && tolower($1)=="hostname" {print $2; exit}
    ' "$CONFIG_FILE")
    MENU+=("$alias" "$ip")
    HOST_MAP["$alias"]="$ip"
done

# Show whiptail menu
CHOICE=$(whiptail --title "SSH Server Menu" \
    --menu "Select a server to connect:" 20 70 10 \
    "${MENU[@]}" \
    3>&1 1>&2 2>&3)

exitstatus=$?

if [ $exitstatus -eq 0 ]; then
    if [[ "$CHOICE" == "Last" ]]; then
        HOST="$LAST"
        echo "Reconnecting to $HOST..."
    else
        HOST="$CHOICE"
        echo "Connecting to $HOST (${HOST_MAP[$HOST]})..."
    fi
    echo "$HOST" > "$LAST_FILE"
    ssh "$HOST"
else
    echo "Cancelled."
fi
