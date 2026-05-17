#!/usr/bin/env bash

# SSH Manager - Hybrid Interface (FZF + Whiptail)
# FZF for fast selections, Whiptail for forms and confirmations

KEY_DIR="$HOME/.ssh"
HISTORY_FILE="$HOME/.ssh_manager_history"
CONFIG_FILE="$KEY_DIR/config"
BACKTITLE="SSH Key Manager v2.0 | $(whoami)@$(hostname)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

mkdir -p "$KEY_DIR"
touch "$HISTORY_FILE" "$CONFIG_FILE"
chmod 600 "$HISTORY_FILE" "$CONFIG_FILE"

# Check dependencies
check_dependencies() {
    local missing=()
    
    command -v fzf &> /dev/null || missing+=("fzf")
    command -v whiptail &> /dev/null || missing+=("whiptail")
    
    if [ ${#missing[@]} -gt 0 ]; then
        clear
        echo -e "${RED}Missing required tools: ${missing[*]}${NC}\n"
        echo "Install with:"
        for tool in "${missing[@]}"; do
            case $tool in
                fzf) echo "  sudo apt install fzf" ;;
                whiptail) echo "  sudo apt install whiptail" ;;
            esac
        done
        echo ""
        exit 1
    fi
}

# === Helper Functions ===

save_history() {
    local key="$1"
    local server="$2"
    local result="$3"
    grep -v "^$key|$server|" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" 2>/dev/null
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    echo "$key|$server|$result|$(date '+%Y-%m-%d %H:%M:%S')" >> "$HISTORY_FILE"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║  ███████╗███████╗██╗  ██╗    ███╗   ███╗ ██████╗ ██████╗ ║
║  ██╔════╝██╔════╝██║  ██║    ████╗ ████║██╔════╝ ██╔══██╗║
║  ███████╗███████╗███████║    ██╔████╔██║██║  ███╗██████╔╝║
║  ╚════██║╚════██║██╔══██║    ██║╚██╔╝██║██║   ██║██╔══██╗║
║  ███████║███████║██║  ██║    ██║ ╚═╝ ██║╚██████╔╝██║  ██║║
║  ╚══════╝╚══════╝╚═╝  ╚═╝    ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝║
║                                                           ║
║            FZF + Whiptail Hybrid Interface               ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    sleep 0.5
}

# === Core Functions ===

generate_key() {
    # FZF for quick key type selection
    local KEY_TYPE=$(cat <<EOF | fzf --height 40% --border --prompt="❯ Select key type: " --header="↑↓ Navigate | Enter: Select | Esc: Cancel" --color=prompt:cyan,pointer:green,header:yellow
ed25519  ⭐ Recommended (fast, secure, modern - 256-bit)
rsa      📦 Legacy compatible (slower - 4096-bit)
ecdsa    🔐 Elliptic Curve (alternative - 521-bit)
EOF
)
    
    [ -z "$KEY_TYPE" ] && return
    KEY_TYPE=$(echo "$KEY_TYPE" | awk '{print $1}')
    
    local DEFAULT_KEY_NAME EXTRA_OPTS DESC
    case $KEY_TYPE in
        ed25519) 
            DEFAULT_KEY_NAME="id_ed25519_$(date +%Y%m%d)"
            EXTRA_OPTS="-a 100"
            DESC="Modern, fast, and secure. Recommended for new keys."
            ;;
        rsa)
            DEFAULT_KEY_NAME="id_rsa_$(date +%Y%m%d)"
            EXTRA_OPTS="-b 4096"
            DESC="Traditional RSA 4096-bit. Good for legacy systems."
            ;;
        ecdsa)
            DEFAULT_KEY_NAME="id_ecdsa_$(date +%Y%m%d)"
            EXTRA_OPTS="-b 521"
            DESC="Elliptic Curve 521-bit. Compact and efficient."
            ;;
    esac
    
    # Whiptail for structured input
    local KEY_NAME=$(whiptail --backtitle "$BACKTITLE" --title "🔑 Key Name" \
        --inputbox "Enter a unique name for your $KEY_TYPE key:\n\n$DESC" 12 70 "$DEFAULT_KEY_NAME" 3>&1 1>&2 2>&3)
    
    [ $? -ne 0 ] && return
    [ -z "$KEY_NAME" ] && return
    
    local EMAIL=$(whiptail --backtitle "$BACKTITLE" --title "📧 Key Comment" \
        --inputbox "Enter your email or identifier:\n(Used as a comment to identify this key)" 10 70 "$(whoami)@$(hostname)" 3>&1 1>&2 2>&3)
    
    [ $? -ne 0 ] && return
    
    local KEY_PATH="$KEY_DIR/$KEY_NAME"
    
    if [ -f "$KEY_PATH" ]; then
        whiptail --backtitle "$BACKTITLE" --title "⚠️  Warning" \
            --msgbox "Key already exists at:\n$KEY_PATH\n\nPlease choose a different name." 10 70
        return
    fi
    
    # Whiptail progress gauge
    {
        echo "10"; echo "# Generating $KEY_TYPE key with $EXTRA_OPTS..."
        sleep 0.5
        ssh-keygen -t "$KEY_TYPE" $EXTRA_OPTS -C "$EMAIL" -f "$KEY_PATH" -N "" >/dev/null 2>&1
        echo "70"; echo "# Setting secure permissions..."
        chmod 600 "$KEY_PATH"
        chmod 644 "$KEY_PATH.pub"
        echo "100"; echo "# Key generated successfully!"
        sleep 1
    } | whiptail --backtitle "$BACKTITLE" --title "Generating Key" --gauge "Please wait..." 8 70 0
    
    if [ -f "$KEY_PATH" ]; then
        local FINGERPRINT=$(ssh-keygen -l -f "$KEY_PATH" 2>/dev/null | awk '{print $2}')
        local PUBKEY=$(cat "$KEY_PATH.pub")
        
        whiptail --backtitle "$BACKTITLE" --title "✅ Success" --msgbox \
"SSH key generated successfully!

Type:        $KEY_TYPE
Location:    $KEY_PATH
Fingerprint: $FINGERPRINT

Public Key (first 70 chars):
${PUBKEY:0:70}...

You can now deploy this key to servers." 18 78
    else
        whiptail --backtitle "$BACKTITLE" --title "❌ Error" \
            --msgbox "Failed to generate SSH key!" 8 50
    fi
}

copy_key() {
    # FZF to select key
    local KEYS=$(ls -1 "$KEY_DIR" | grep -vE '\.(pub|old)$|^(known_hosts|config|authorized_keys)')
    
    if [ -z "$KEYS" ]; then
        whiptail --backtitle "$BACKTITLE" --title "No Keys" \
            --msgbox "No SSH keys found!\n\nGenerate a key first from the main menu." 10 60
        return
    fi
    
    local KEY_FILE=$(echo "$KEYS" | fzf --height 50% --border --prompt="❯ Select key to deploy: " \
        --header="↑↓ Navigate | Enter: Select | Esc: Cancel" \
        --preview="echo 'Key Info:'; echo ''; ssh-keygen -l -f $KEY_DIR/{} 2>/dev/null; echo ''; echo 'Public Key:'; cat $KEY_DIR/{}.pub 2>/dev/null | fold -w 60" \
        --preview-window=right:60%:wrap \
        --color=prompt:cyan,pointer:green,header:yellow)
    
    [ -z "$KEY_FILE" ] && return
    
    local KEY_PATH="$KEY_DIR/$KEY_FILE"
    
    if [ ! -f "$KEY_PATH" ]; then
        whiptail --backtitle "$BACKTITLE" --title "❌ Error" \
            --msgbox "Key not found: $KEY_PATH" 8 60
        return
    fi
    
    # Whiptail for server details
    local REMOTE=$(whiptail --backtitle "$BACKTITLE" --title "📤 Deploy Key - Target Server" \
        --inputbox "Enter destination server:\n\nFormat: username@hostname or username@IP\nExample: root@192.168.1.100" 12 70 "" 3>&1 1>&2 2>&3)
    
    [ $? -ne 0 ] && return
    [ -z "$REMOTE" ] && return
    
    local USERNAME=$(echo "$REMOTE" | cut -d'@' -f1)
    local HOSTNAME=$(echo "$REMOTE" | cut -d'@' -f2)
    
    local ALIAS=$(whiptail --backtitle "$BACKTITLE" --title "📝 SSH Config Alias" \
        --inputbox "Enter a short alias for this server:\n\nThis allows you to connect with: ssh ALIAS\nExample: prod, web1, database" 12 70 "${HOSTNAME%%.*}" 3>&1 1>&2 2>&3)
    
    [ $? -ne 0 ] && return
    [ -z "$ALIAS" ] && ALIAS="$HOSTNAME"
    
    # Show deployment summary with whiptail
    if ! whiptail --backtitle "$BACKTITLE" --title "🚀 Confirm Deployment" --yesno \
"Ready to deploy SSH key:

Key:      $KEY_FILE
Server:   $REMOTE
Alias:    $ALIAS

Actions:
  1. Copy public key to $REMOTE
  2. Update ~/.ssh/config with alias
  3. Test passwordless connection

Proceed with deployment?" 18 70; then
        return
    fi
    
    # Deploy with progress gauge
    {
        echo "10"; echo "# Copying public key to $REMOTE..."
        sleep 0.5
        
        if ssh-copy-id -i "$KEY_PATH.pub" "$REMOTE" 2>/tmp/sshcopy_error.log; then
            echo "40"; echo "# Key copied successfully!"
            sleep 0.5
            
            echo "50"; echo "# Updating SSH config..."
            # Backup config
            cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%s)" 2>/dev/null
            
            # Remove old entry
            awk -v h="$ALIAS" 'BEGIN{skip=0} /^Host /{skip=($2==h)?1:0} !skip{print}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
            mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            
            # Add new entry
            {
                echo ""
                echo "Host $ALIAS"
                echo "    HostName $HOSTNAME"
                echo "    User $USERNAME"
                echo "    IdentityFile $KEY_PATH"
                echo "    IdentitiesOnly yes"
            } >> "$CONFIG_FILE"
            
            echo "70"; echo "# Config updated!"
            sleep 0.5
            
            echo "80"; echo "# Testing passwordless login..."
            sleep 0.5
            
            if ssh -i "$KEY_PATH" -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE" "echo 'test'" >/dev/null 2>&1; then
                save_history "$KEY_FILE" "$REMOTE" "success"
                echo "100"; echo "# Connection verified!"
            else
                save_history "$KEY_FILE" "$REMOTE" "partial"
                echo "100"; echo "# Key copied but verification failed"
            fi
        else
            save_history "$KEY_FILE" "$REMOTE" "fail"
            echo "100"; echo "# Failed to copy key"
        fi
        sleep 1
    } | whiptail --backtitle "$BACKTITLE" --title "🚀 Deploying Key" --gauge "Please wait..." 8 70 0
    
    # Show result
    if ssh -i "$KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE" "echo 'test'" >/dev/null 2>&1; then
        whiptail --backtitle "$BACKTITLE" --title "🎉 Success" --msgbox \
"Key deployed successfully!

✓ Public key copied to $REMOTE
✓ SSH config updated (alias: $ALIAS)
✓ Passwordless login verified

Quick connect:
  ssh $ALIAS

Manual connect:
  ssh -i $KEY_PATH $REMOTE" 16 70
    else
        local ERROR_MSG=$(cat /tmp/sshcopy_error.log 2>/dev/null | head -20)
        whiptail --backtitle "$BACKTITLE" --title "⚠️  Partial Success" --msgbox \
"Key copied but verification failed.

Possible issues:
• SSH server configuration
• Firewall blocking connections
• Wrong username or hostname
• Server key restrictions

Try manually:
  ssh -i $KEY_PATH $REMOTE

Error log:
${ERROR_MSG:-No error details available}" 20 75 --scrolltext
    fi
}

test_login() {
    # Whiptail for server input
    local REMOTE=$(whiptail --backtitle "$BACKTITLE" --title "🔍 Test Connection" \
        --inputbox "Enter server to test:\n\nFormat: username@hostname\nExample: user@example.com" 10 70 "" 3>&1 1>&2 2>&3)
    
    [ $? -ne 0 ] && return
    [ -z "$REMOTE" ] && return
    
    # FZF to select key
    local KEYS=$(ls -1 "$KEY_DIR" | grep -vE '\.(pub|old)$|^(known_hosts|config|authorized_keys)')
    
    local KEY_FILE=$(echo "$KEYS" | fzf --height 40% --border --prompt="❯ Select key to test: " \
        --preview="ssh-keygen -l -f $KEY_DIR/{} 2>/dev/null" \
        --color=prompt:cyan,pointer:green)
    
    [ -z "$KEY_FILE" ] && return
    
    local KEY_PATH="$KEY_DIR/$KEY_FILE"
    
    # Test with progress
    {
        echo "20"; echo "# Resolving hostname..."
        sleep 0.5
        echo "40"; echo "# Connecting to $REMOTE..."
        sleep 0.5
        echo "60"; echo "# Authenticating with key..."
        
        if ssh -i "$KEY_PATH" -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE" "echo 'Connected'" 2>/tmp/sshlogin_error.log; then
            save_history "$KEY_FILE" "$REMOTE" "success"
            echo "100"; echo "# Connection successful!"
        else
            save_history "$KEY_FILE" "$REMOTE" "fail"
            echo "100"; echo "# Connection failed"
        fi
        sleep 1
    } | whiptail --backtitle "$BACKTITLE" --title "Testing Connection" --gauge "Please wait..." 8 70 0
    
    if ssh -i "$KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE" "echo 'test'" >/dev/null 2>&1; then
        whiptail --backtitle "$BACKTITLE" --title "🎉 Success" --msgbox \
"Passwordless authentication works!

Server:  $REMOTE
Key:     $KEY_FILE

✓ Connection established
✓ Authentication successful
✓ SSH key is properly configured" 13 70
    else
        local ERROR_MSG=$(cat /tmp/sshlogin_error.log 2>/dev/null)
        whiptail --backtitle "$BACKTITLE" --title "❌ Connection Failed" --msgbox \
"Connection test failed for $REMOTE

Common causes:
• Server not reachable (check network)
• Wrong username
• SSH key not authorized on server
• SSH service not running
• Firewall blocking port 22

Error details:
${ERROR_MSG:-No specific error captured}

Troubleshooting:
  ssh -v -i $KEY_PATH $REMOTE" 20 75 --scrolltext
    fi
}

list_keys() {
    local KEYS_INFO=""
    local count=0
    
    for key in "$KEY_DIR"/*; do
        [ ! -f "$key" ] && continue
        [[ "$key" =~ \.(pub|old)$ ]] && continue
        [[ "$(basename "$key")" =~ ^(known_hosts|config|authorized_keys) ]] && continue
        
        local name=$(basename "$key")
        local info=$(ssh-keygen -l -f "$key" 2>/dev/null)
        local type=$(echo "$info" | awk '{print $NF}' | tr -d '()')
        local size=$(echo "$info" | awk '{print $1}')
        local fingerprint=$(echo "$info" | awk '{print $2}')
        
        KEYS_INFO+="$name\n"
        KEYS_INFO+="  Type: ${type:-Unknown}  Size: ${size:-N/A}\n"
        KEYS_INFO+="  Fingerprint: ${fingerprint:-N/A}\n\n"
        count=$((count + 1))
    done
    
    [ $count -eq 0 ] && KEYS_INFO="No SSH keys found in ~/.ssh/\n\nGenerate a key from the main menu."
    
    whiptail --backtitle "$BACKTITLE" --title "🔑 SSH Keys in ~/.ssh (Total: $count)" \
        --msgbox "$KEYS_INFO" 25 80 --scrolltext
}

delete_key() {
    # FZF to select key to delete
    local KEYS=$(ls -1 "$KEY_DIR" | grep -vE '\.(pub|old)$|^(known_hosts|config|authorized_keys)')
    
    if [ -z "$KEYS" ]; then
        whiptail --backtitle "$BACKTITLE" --title "No Keys" \
            --msgbox "No SSH keys available to delete." 8 50
        return
    fi
    
    local KEY_FILE=$(echo "$KEYS" | fzf --height 50% --border --prompt="❯ Select key to DELETE: " \
        --header="⚠️  WARNING: This action cannot be undone! | Esc: Cancel" \
        --preview="echo 'Key Info:'; ssh-keygen -l -f $KEY_DIR/{} 2>/dev/null; echo ''; echo 'This will delete:'; echo '  - $KEY_DIR/{}'; echo '  - $KEY_DIR/{}.pub'" \
        --preview-window=right:50%:wrap \
        --color=prompt:red,pointer:red,header:yellow)
    
    [ -z "$KEY_FILE" ] && return
    
    # Whiptail confirmation
    if whiptail --backtitle "$BACKTITLE" --title "🗑️  Confirm Deletion" --yesno \
"Are you sure you want to permanently delete:

  $KEY_FILE
  $KEY_FILE.pub

This action CANNOT be undone!

The key will be removed from:
• Local filesystem (~/.ssh/)
• Connection history

SSH config entries will remain (you can remove them separately)." 18 75 --defaultno; then
        
        rm -f "$KEY_DIR/$KEY_FILE" "$KEY_DIR/$KEY_FILE.pub"
        grep -v "^$KEY_FILE|" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" 2>/dev/null
        mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
        
        whiptail --backtitle "$BACKTITLE" --title "✅ Deleted" --msgbox \
"Key removed successfully:

✓ $KEY_FILE
✓ $KEY_FILE.pub
✓ History entries cleared

Note: If this key was deployed to servers, you may want to remove
it from their ~/.ssh/authorized_keys files." 13 70
    fi
}

connect_server() {
    local HOSTS=$(awk '/^Host[[:space:]]+/ && $2 !~ /\*/ {print $2}' "$CONFIG_FILE")
    
    if [ -z "$HOSTS" ]; then
        whiptail --backtitle "$BACKTITLE" --title "No Servers" \
            --msgbox "No servers configured yet!\n\nAdd servers using 'Deploy Key to Server' from the main menu." 10 70
        return
    fi
    
    # FZF with preview for server selection
    local SELECTED=$(echo "$HOSTS" | fzf --height 60% --border --prompt="❯ Select server to connect: " \
        --header="↑↓ Navigate | Enter: Connect | Esc: Cancel" \
        --preview="awk -v h={} '\$1==\"Host\" && \$2==h {found=1; print \"📋 SSH Config Entry:\n\"} found && /^Host / && \$2!=h {found=0} found {print \"  \" \$0}' $CONFIG_FILE" \
        --preview-window=right:50%:wrap \
        --color=prompt:cyan,pointer:green,header:yellow)
    
    if [ -n "$SELECTED" ]; then
        local HOSTNAME=$(awk -v h="$SELECTED" '$1=="Host" && $2==h {found=1} found && $1=="HostName" {print $2; exit}' "$CONFIG_FILE")
        local USER=$(awk -v h="$SELECTED" '$1=="Host" && $2==h {found=1} found && $1=="User" {print $2; exit}' "$CONFIG_FILE")
        
        clear
        echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  Connecting to: ${BOLD}$SELECTED${NC}${GREEN}"
        echo -e "${GREEN}║  Server: ${USER}@${HOSTNAME}${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
        echo -e "${YELLOW}Press Ctrl+D or type 'exit' to return to menu${NC}\n"
        
        ssh "$SELECTED"
        
        echo -e "\n${CYAN}Connection closed. Press Enter to continue...${NC}"
        read
    fi
}

delete_host_config() {
    local HOSTS=$(awk '/^Host[[:space:]]+/ && $2 !~ /\*/ {print $2}' "$CONFIG_FILE")
    
    if [ -z "$HOSTS" ]; then
        whiptail --backtitle "$BACKTITLE" --title "No Hosts" \
            --msgbox "No hosts found in SSH config." 8 50
        return
    fi
    
    # FZF to select host
    local HOST=$(echo "$HOSTS" | fzf --height 50% --border --prompt="❯ Select host to REMOVE: " \
        --header="⚠️  This removes the SSH config entry only | Esc: Cancel" \
        --preview="awk -v h={} '\$1==\"Host\" && \$2==h {f=1; print \"Config entry to be removed:\n\"} f && /^Host / && \$2!=h {f=0} f {print \"  \" \$0}' $CONFIG_FILE" \
        --preview-window=right:50%:wrap \
        --color=prompt:red,pointer:red,header:yellow)
    
    [ -z "$HOST" ] && return
    
    # Whiptail confirmation
    if whiptail --backtitle "$BACKTITLE" --title "🗑️  Confirm Removal" --yesno \
"Remove host '$HOST' from SSH config?

This will:
✓ Remove the config entry from ~/.ssh/config
✓ Create a backup of the config file
✗ NOT delete the SSH key itself
✗ NOT remove the key from the server

You can still connect manually with:
  ssh user@hostname -i ~/.ssh/keyfile" 16 70; then
        
        cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%s)"
        awk -v host="$HOST" 'BEGIN{skip=0} $1=="Host" && $2==host {skip=1; next} skip && $1=="Host" {skip=0} !skip {print}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        
        whiptail --backtitle "$BACKTITLE" --title "✅ Removed" --msgbox \
"Host '$HOST' removed from SSH config.

✓ Config entry deleted
✓ Backup saved with timestamp

The SSH key itself was NOT deleted.
To remove keys, use 'Delete SSH Key' from the main menu." 12 70
    fi
}

list_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        whiptail --backtitle "$BACKTITLE" --title "📜 Connection History" \
            --msgbox "No connection history yet!\n\nConnect to servers to build your history." 10 60
        return
    fi
    
    local HISTORY_TEXT=""
    local total=0
    local success=0
    
    while IFS='|' read -r key server result timestamp; do
        [ -z "$key" ] && continue
        total=$((total + 1))
        
        local icon="❌"
        if [ "$result" = "success" ]; then
            icon="✅"
            success=$((success + 1))
        fi
        
        HISTORY_TEXT+="$icon $timestamp\n"
        HISTORY_TEXT+="   Key: $key\n"
        HISTORY_TEXT+="   Server: $server\n"
        HISTORY_TEXT+="   Status: $result\n\n"
    done < "$HISTORY_FILE"
    
    local success_rate=$(awk "BEGIN {printf \"%.1f\", ($success/$total)*100}")
    
    whiptail --backtitle "$BACKTITLE" --title "📜 Connection History (Total: $total | Success Rate: $success_rate%)" \
        --msgbox "$HISTORY_TEXT" 25 80 --scrolltext
}

show_stats() {
    local total_keys=$(find "$KEY_DIR" -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "config*" ! -name "authorized_keys" 2>/dev/null | wc -l)
    local total_hosts=$(awk '/^Host[[:space:]]+/ && $2 !~ /\*/ {count++} END {print count+0}' "$CONFIG_FILE")
    local total_conn=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)
    local success_rate="N/A"
    
    if [ "$total_conn" -gt 0 ]; then
        local successes=$(grep -c "|success|" "$HISTORY_FILE" 2>/dev/null || echo 0)
        success_rate=$(awk "BEGIN {printf \"%.1f%%\", ($successes/$total_conn)*100}")
    fi
    
    local recent_conn="None"
    if [ -s "$HISTORY_FILE" ]; then
        recent_conn=$(tail -1 "$HISTORY_FILE" | cut -d'|' -f2,4 | tr '|' ' @ ')
    fi
    
    whiptail --backtitle "$BACKTITLE" --title "📊 SSH Manager Statistics" --msgbox \
"System Overview:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔑 Total SSH Keys:        $total_keys
🌐 Configured Hosts:      $total_hosts
📊 Total Connections:     $total_conn
✅ Success Rate:          $success_rate

📅 Most Recent Connection:
   $recent_conn

📁 Configuration:
   Keys:    $KEY_DIR
   Config:  $CONFIG_FILE
   History: $HISTORY_FILE" 20 70
}

# === Main Menu ===

check_dependencies
show_banner

while true; do
    # FZF main menu with nice formatting
    CHOICE=$(cat <<EOF | fzf --height 70% --border --prompt="❯ Main Menu: " --pointer="▶" \
        --header="SSH Key Manager | Use ↑↓ arrows, Enter to select, Esc to exit" \
        --color=prompt:cyan,pointer:green,header:yellow,border:blue
🌐  Connect to Server          │ SSH into configured servers
🔑  Generate New SSH Key       │ Create ed25519, RSA, or ECDSA keys
📤  Deploy Key to Server       │ Copy key and update SSH config
🔍  Test Connection            │ Verify passwordless authentication
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋  List All Keys              │ View all SSH keys with details
📜  View Connection History    │ See past connections and status
📊  Show Statistics            │ Dashboard with system overview
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🗑️   Delete SSH Key            │ Permanently remove a key
🗑️   Remove Host Config        │ Delete host from SSH config
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚪  Exit                       │ Quit SSH Manager
EOF
)

    [ -z "$CHOICE" ] && { clear; echo -e "${GREEN}Goodbye!${NC}"; exit 0; }

    case "$CHOICE" in
        *"Connect to Server"*) connect_server ;;
        *"Generate New"*) generate_key ;;
        *"Deploy Key"*) copy_key ;;
        *"Test Connection"*) test_login ;;
        *"List All Keys"*) list_keys ;;
        *"Connection History"*) list_history ;;
        *"Statistics"*) show_stats ;;
        *"Delete SSH Key"*) delete_key ;;
        *"Remove Host"*) delete_host_config ;;
        *"Exit"*) clear; echo -e "${GREEN}Thank you for using SSH Manager!${NC}"; exit 0 ;;
    esac
done