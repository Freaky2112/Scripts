#!/usr/bin/env bash

set -euo pipefail

# Configuration
readonly KEY_DIR="$HOME/.ssh"
readonly HISTORY_FILE="$HOME/.ssh_manager_history"
readonly CONFIG_FILE="$KEY_DIR/config"
readonly TEMP_ERROR_LOG="/tmp/ssh_manager_error.log"

# Cleanup trap
cleanup() {
    rm -f "${CONFIG_FILE}.tmp" "${HISTORY_FILE}.tmp" "$TEMP_ERROR_LOG"
}
trap cleanup EXIT

# Initialize directories and files
init_environment() {
    mkdir -p "$KEY_DIR"
    touch "$HISTORY_FILE" "$CONFIG_FILE"
    chmod 600 "$HISTORY_FILE" "$CONFIG_FILE" "$KEY_DIR"
}

# ============================================================================
# History Management
# ============================================================================

save_history() {
    local key="$1" server="$2" result="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local temp_history
    temp_history=$(mktemp)
    # Remove existing entry for this key+server combination
    grep -v "^${key}|${server}|" "$HISTORY_FILE" > "$temp_history" 2>/dev/null || true
    mv "$temp_history" "$HISTORY_FILE"
    
    echo "${key}|${server}|${result}|${timestamp}" >> "$HISTORY_FILE"
}

list_history() {
    local menu_items=()
    
    if [[ ! -s "$HISTORY_FILE" ]]; then
        whiptail --msgbox "No server history yet!" 10 50
        return
    fi
    
    while IFS='|' read -r key server result timestamp; do
        local icon="❌"
        [[ "$result" == "success" ]] && icon="✅"
        menu_items+=("${key}@${server}" "${icon} Last: ${timestamp}")
    done < "$HISTORY_FILE"
    
    whiptail --title "📜 Server History" --menu "Recent connections:" 20 70 10 "${menu_items[@]}"
}

# ============================================================================
# SSH Key Generation
# ============================================================================

generate_key() {
    local key_type key_name email key_path extra_opts
    
    key_type=$(whiptail --title "🔑 Generate SSH Key" --menu "Choose key type:" 15 50 3 \
        "ed25519" "Recommended (fast + secure)" \
        "rsa" "Legacy compatibility (4096 bits)" \
        "ecdsa" "Elliptic Curve (521 bits)" 3>&1 1>&2 2>&3) || return
    
    case $key_type in
        ed25519) 
            key_name="id_ed25519_custom"
            extra_opts="-a 100"
            ;;
        rsa)
            key_name="id_rsa_custom"
            extra_opts="-b 4096"
            ;;
        ecdsa)
            key_name="id_ecdsa_custom"
            extra_opts="-b 521"
            ;;
    esac
    
    key_name=$(whiptail --inputbox "Enter key name:" 10 50 "$key_name" 3>&1 1>&2 2>&3) || return
    email=$(whiptail --inputbox "Email (for key comment):" 10 50 "$(whoami)@$(hostname)" 3>&1 1>&2 2>&3) || return
    key_path="${KEY_DIR}/${key_name}"
    
    if [[ -f "$key_path" ]]; then
        whiptail --msgbox "⚠️  Key already exists: ${key_path}" 10 50
        return 1
    fi
    
    if ssh-keygen -t "$key_type" $extra_opts -C "$email" -f "$key_path" -N ""; then
        whiptail --msgbox "✅ ${key_type} key generated:\n${key_path}" 10 60
    else
        whiptail --msgbox "❌ Failed to generate SSH key" 10 50
        return 1
    fi
}

# ============================================================================
# SSH Config Management
# ============================================================================

update_ssh_config() {
    local key="$1" user="$2" host="$3"
    local backup_file
    
    # Create backup
    backup_file="${CONFIG_FILE}.bak.$(date +%F_%T)"
    cp "$CONFIG_FILE" "$backup_file" 2>/dev/null || true
    
    # Remove old entry for this host
    local temp_config
    temp_config=$(mktemp)
    awk -v h="$host" '
        BEGIN { skip=0 }
        /^Host[[:space:]]+/{ if ($2 == h) {skip=1} else {skip=0} }
        /^[[:space:]]*$/ { skip=0 } # Reset on blank lines
        !skip { print }
    ' "$CONFIG_FILE" > "$temp_config"
    mv "$temp_config" "$CONFIG_FILE"
    
    # Add new entry
    cat >> "$CONFIG_FILE" << EOF

Host $host
    HostName $host
    User $user
    IdentityFile ${KEY_DIR}/${key}
    IdentitiesOnly yes
EOF
    
    whiptail --msgbox "📝 SSH config updated for ${user}@${host}" 10 60
}

delete_host_config() {
    local hosts host_to_delete
    
    hosts=$(awk '/^Host[[:space:]]+/ && $2 !~ /\*/ {print $2}' "$CONFIG_FILE")
    
    if [[ -z "$hosts" ]]; then
        whiptail --msgbox "No hosts found in SSH config" 10 50
        return
    fi
    
    local menu_items=()
    while IFS= read -r h; do
        menu_items+=("$h" "")
    done <<< "$hosts"
    
    host_to_delete=$(whiptail --title "Delete SSH Config Host" --menu "Select host to delete:" 20 60 10 "${menu_items[@]}" 3>&1 1>&2 2>&3) || return
    
    if ! whiptail --yesno "Delete host [${host_to_delete}] from SSH config?" 10 60; then
        return
    fi
    
    # Backup before deletion
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%F_%T)"
    
    # Remove host block
    local temp_config
    temp_config=$(mktemp)
    awk -v host="$host_to_delete" '
        BEGIN { skip=0 }
        /^Host[[:space:]]+/ && $2==host { skip=1; next }
        /^[[:space:]]*$/ { skip=0 } # Reset on blank lines
        !skip { print }
    ' "$CONFIG_FILE" > "$temp_config"
    mv "$temp_config" "$CONFIG_FILE"
    
    whiptail --msgbox "🗑️  Host [${host_to_delete}] deleted from SSH config" 10 60
}

# ============================================================================
# Key Management
# ============================================================================

list_keys() {
    local keys
    keys=$(find "$KEY_DIR" -maxdepth 1 -type f -not -name "*.pub" -not -name "known_hosts*" -not -name "config*" -not -name "authorized_keys" | sed "s#^${KEY_DIR}/##" | sort)
    
    if [[ -z "$keys" ]]; then
        whiptail --msgbox "No SSH keys found in ${KEY_DIR}" 10 50
        return
    fi
    
    whiptail --scrolltext --msgbox "📂 SSH Keys in ~/.ssh:\n\n${keys}" 20 60
}

delete_key() {
    local keys key_file
    
    keys=$(find "$KEY_DIR" -maxdepth 1 -type f -not -name "*.pub" -not -name "known_hosts*" -not -name "config*" -not -name "authorized_keys" | sed "s#^${KEY_DIR}/##" | sort)
    
    if [[ -z "$keys" ]]; then
        whiptail --msgbox "No keys to delete" 10 40
        return
    fi
    
    local menu_items=()
    while IFS= read -r k; do
        menu_items+=("$k" "")
    done <<< "$keys"
    
    key_file=$(whiptail --menu "Select key to delete:" 20 60 10 "${menu_items[@]}" 3>&1 1>&2 2>&3) || return
    
    if ! whiptail --yesno "Delete ${key_file} and its public key?" 10 60; then
        return
    fi
    
    rm -f "${KEY_DIR}/${key_file}" "${KEY_DIR}/${key_file}.pub"
    
    # Remove from history
    local temp_history
    temp_history=$(mktemp)
    grep -v "^${key_file}|" "$HISTORY_FILE" > "$temp_history" 2>/dev/null || true
    mv "$temp_history" "$HISTORY_FILE"
    
    whiptail --msgbox "🗑️  ${key_file} deleted successfully" 10 50
}

# ============================================================================
# Server Operations
# ============================================================================

copy_key() {
    local key_file remote username hostname
    
    key_file=$(whiptail --inputbox "Key filename (without .pub):" 10 60 "" 3>&1 1>&2 2>&3) || return
    remote=$(whiptail --inputbox "Destination (user@host):" 10 50 3>&1 1>&2 2>&3) || return
    
    if [[ ! "$remote" =~ ^[^@]+@[^@]+$ ]]; then
        whiptail --msgbox "❌ Invalid format. Use: user@hostname" 10 50
        return 1
    fi
    
    username="${remote%%@*}"
    hostname="${remote#*@}"
    
    if [[ ! -f "${KEY_DIR}/${key_file}.pub" ]]; then
        whiptail --msgbox "❌ Public key not found: ${KEY_DIR}/${key_file}.pub" 10 60
        return 1
    fi
    
    if ssh-copy-id -i "${KEY_DIR}/${key_file}.pub" "$remote" 2>"$TEMP_ERROR_LOG"; then
        whiptail --msgbox "✅ Key copied to ${remote}" 10 60
        update_ssh_config "$key_file" "$username" "$hostname"
        test_connection "$key_file" "$remote"
    else
        local error_msg
        error_msg=$(<"$TEMP_ERROR_LOG")
        whiptail --scrolltext --msgbox "❌ Failed to copy key\n\n${error_msg}" 15 70
        save_history "$key_file" "$remote" "fail"
    fi
}

test_connection() {
    local key_file="$1" remote="$2"
    
    if ssh -i "${KEY_DIR}/${key_file}" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$remote" "echo 'OK'" 2>"$TEMP_ERROR_LOG" >/dev/null; then
        whiptail --msgbox "🎉 Passwordless login works for ${remote}" 10 60
        save_history "$key_file" "$remote" "success"
        return 0
    else
        local error_msg
        error_msg=$(<"$TEMP_ERROR_LOG")
        whiptail --scrolltext --msgbox "⚠️  Login test failed for ${remote}\n\n${error_msg}" 15 70
        save_history "$key_file" "$remote" "fail"
        return 1
    fi
}

test_login() {
    local remote key_file
    
    remote=$(whiptail --inputbox "Test login (user@host):" 10 50 3>&1 1>&2 2>&3) || return
    key_file=$(whiptail --inputbox "Key filename to use:" 10 50 "" 3>&1 1>&2 2>&3) || return
    
    test_connection "$key_file" "$remote"
}

connect_server() {
    local hosts
    
    hosts=$(awk '/^Host[[:space:]]+/ && $2 !~ /\*/ {print $2}' "$CONFIG_FILE")
    
    if [[ -z "$hosts" ]]; then
        whiptail --msgbox "No hosts in SSH config. Add one first!" 10 50
        return
    fi
    
    local menu_items=()
    while IFS= read -r h; do
        menu_items+=("$h" "")
    done <<< "$hosts"
    
    local selected_host
    selected_host=$(whiptail --title "Connect to Server" --menu "Select host:" 20 60 10 "${menu_items[@]}" 3>&1 1>&2 2>&3) || return
    
    if [[ -n "$selected_host" ]]; then
        clear
        echo "Connecting to ${selected_host}..."
        echo "Use Ctrl+D or 'exit' to return"
        echo "----------------------------------------"
        ssh "$selected_host"
    fi
}

# ============================================================================
# Main Menu
# ============================================================================

show_menu() {
    whiptail --title "🔑 SSH Key Manager" --menu "Choose an option:" 22 60 11 \
        "1" "Connect to server" \
        "2" "Generate new SSH key" \
        "3" "Copy key to server" \
        "4" "Test passwordless login" \
        "5" "List existing keys" \
        "6" "Delete a key" \
        "7" "Delete host from config" \
        "8" "Show connection history" \
        "9" "Exit" 3>&1 1>&2 2>&3
}

main() {
    init_environment
    
    while true; do
        choice=$(show_menu) || exit 0
        
        case $choice in
            1) connect_server ;;
            2) generate_key ;;
            3) copy_key ;;
            4) test_login ;;
            5) list_keys ;;
            6) delete_key ;;
            7) delete_host_config ;;
            8) list_history ;;
            9) exit 0 ;;
            *) whiptail --msgbox "Invalid option" 10 40 ;;
        esac
    done
}

main "$@"
