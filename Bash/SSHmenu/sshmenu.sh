#!/usr/bin/env bash

# SSH Manager version 2.2.0
# Full-featured SSH Key & Server Manager with config updates and history

KEY_DIR="$HOME/.ssh"
HISTORY_FILE="$HOME/.ssh_manager_history"
CONFIG_FILE="$KEY_DIR/config"

mkdir -p "$KEY_DIR"
touch "$HISTORY_FILE" "$CONFIG_FILE"
chmod 600 "$HISTORY_FILE" "$CONFIG_FILE"

# --- Helper Functions ---

save_history() {
    local key="$1"
    local server="$2"
    local result="$3"
    grep -v "^$key|$server|" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" 2>/dev/null
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    echo "$key|$server|$result|$(date '+%Y-%m-%d %H:%M:%S')" >> "$HISTORY_FILE"
}

list_history() {
    MENU_ITEMS=()
    while read -r line; do
        key=$(echo "$line" | cut -d'|' -f1)
        server=$(echo "$line" | cut -d'|' -f2)
        result=$(echo "$line" | cut -d'|' -f3)
        last=$(echo "$line" | cut -d'|' -f4)
        ICON="❌"
        [ "$result" = "success" ] && ICON="✅"
        MENU_ITEMS+=("$key@$server" "$ICON Last login: $last")
    done < "$HISTORY_FILE"

    [ ${#MENU_ITEMS[@]} -eq 0 ] && { whiptail --msgbox "No server history yet!" 10 50; return; }

    whiptail --title "📜 Server History" --msgbox "$(printf "%-30s %s\n" "${MENU_ITEMS[@]}")" 20 70
}

# --- Core Functions ---

generate_key() {
    KEY_TYPE=$(whiptail --title "🔑 Generate SSH Key" --menu "Choose key type:" 15 50 4 \
        "ed25519" "Recommended (fast + secure)" \
        "rsa" "Legacy (4096 bits)" \
        "ecdsa" "Elliptic Curve (521 bits)" 3>&1 1>&2 2>&3) || return

    case $KEY_TYPE in
        ed25519) DEFAULT_KEY_NAME="id_ed25519_custom"; EXTRA_OPTS="-a 100" ;;
        rsa)     DEFAULT_KEY_NAME="id_rsa_custom";    EXTRA_OPTS="-b 4096" ;;
        ecdsa)   DEFAULT_KEY_NAME="id_ecdsa_custom";  EXTRA_OPTS="-b 521" ;;
    esac

    KEY_NAME=$(whiptail --inputbox "Enter key name:" 10 50 "$DEFAULT_KEY_NAME" 3>&1 1>&2 2>&3) || return
    EMAIL=$(whiptail --inputbox "Enter your email (for key comment):" 10 50 "$(whoami)@$(hostname)" 3>&1 1>&2 2>&3) || return
    KEY_PATH="$KEY_DIR/$KEY_NAME"

    if [ -f "$KEY_PATH" ]; then
        whiptail --msgbox "⚠️ Key already exists at $KEY_PATH" 10 50
    else
        ssh-keygen -t "$KEY_TYPE" $EXTRA_OPTS -C "$EMAIL" -f "$KEY_PATH"
        if [ $? -eq 0 ]; then
            whiptail --msgbox "✅ $KEY_TYPE key generated at $KEY_PATH" 10 50
        else
            whiptail --msgbox "❌ Failed to generate SSH key!" 10 50
        fi
    fi
}

update_ssh_config() {
    local key="$1"
    local user="$2"
    local host="$3"

    # Remove old entry for host
    awk -v h="$host" 'BEGIN{skip=0} /^Host /{skip=($2==h)?1:0} !skip{print}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    # Add new entry
    {
        echo ""
        echo "Host $key"
        echo "    HostName $host"
        echo "    User $user"
        echo "    IdentityFile $KEY_DIR/$key"
    } >> "$CONFIG_FILE"

    whiptail --msgbox "📝 SSH config updated for $user@$host" 10 60
}

copy_key() {
    KEY_FILE=$(whiptail --inputbox "Enter key filename inside ~/.ssh (e.g., id_ed25519_custom)" 10 60 "" 3>&1 1>&2 2>&3) || return
    REMOTE=$(whiptail --inputbox "Enter username@hostname:" 10 50 3>&1 1>&2 2>&3) || return

    USERNAME=$(echo "$REMOTE" | cut -d'@' -f1)
    HOSTNAME=$(echo "$REMOTE" | cut -d'@' -f2)

    if ssh-copy-id -i "$KEY_DIR/$KEY_FILE.pub" "$REMOTE" 2>/tmp/sshcopy_error.log; then
        whiptail --msgbox "✅ Key successfully copied to $REMOTE" 10 60

        # Update SSH config
        update_ssh_config "$KEY_FILE" "$USERNAME" "$HOSTNAME"

        # Test login
        if ssh -i "$KEY_DIR/$KEY_FILE" -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE" "echo 'Connected successfully'" 2>/tmp/sshlogin_error.log; then
            whiptail --msgbox "🎉 Passwordless login works for $REMOTE" 10 60
            save_history "$KEY_FILE" "$REMOTE" "success"
        else
            ERROR_MSG=$(< /tmp/sshlogin_error.log)
            whiptail --msgbox "⚠️ Login test failed for $REMOTE\n\n$ERROR_MSG" 15 70
            save_history "$KEY_FILE" "$REMOTE" "fail"
        fi
    else
        ERROR_MSG=$(< /tmp/sshcopy_error.log)
        whiptail --msgbox "❌ Failed to copy key\n\n$ERROR_MSG" 15 70
        save_history "$KEY_FILE" "$REMOTE" "fail"
    fi
}

test_login() {
    REMOTE=$(whiptail --inputbox "Enter username@hostname to test login:" 10 50 3>&1 1>&2 2>&3) || return
    KEY_FILE=$(whiptail --inputbox "Enter key filename to use:" 10 50 "" 3>&1 1>&2 2>&3) || return

    if ssh -i "$KEY_DIR/$KEY_FILE" -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE" "echo 'Connected successfully'" 2>/tmp/sshlogin_error.log; then
        whiptail --msgbox "🎉 Passwordless login works for $REMOTE" 10 60
        save_history "$KEY_FILE" "$REMOTE" "success"
    else
        ERROR_MSG=$(< /tmp/sshlogin_error.log)
        whiptail --msgbox "⚠️ Login test failed for $REMOTE\n\n$ERROR_MSG" 15 70
        save_history "$KEY_FILE" "$REMOTE" "fail"
    fi
}

list_keys() {
    KEYS=$(ls "$KEY_DIR" | grep -vE "(\.pub|known_hosts|known_hosts.old|config|authorized_keys|config.*|_sshmgr_hist)$" || echo "No keys found")
    whiptail --msgbox "📂 Existing SSH Keys in ~/.ssh:\n\n$KEYS" 20 60
}

delete_key() {
    KEYS=$(ls "$KEY_DIR" | grep -vE "(\.pub|known_hosts|known_hosts.old|config|authorized_keys)$")
    [ -z "$KEYS" ] && { whiptail --msgbox "No keys to delete!" 10 40; return; }

    KEY_FILE=$(whiptail --menu "Select key to delete:" 20 60 10 $(for k in $KEYS; do echo "$k" "$k"; done) 3>&1 1>&2 2>&3) || return

    if (whiptail --yesno "Are you sure you want to delete $KEY_FILE and its .pub file?" 10 60); then
        rm -f "$KEY_DIR/$KEY_FILE" "$KEY_DIR/$KEY_FILE.pub"
        # Remove from history
        grep -v "^$KEY_FILE|" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" 2>/dev/null
        mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
        whiptail --msgbox "🗑️ $KEY_FILE deleted successfully" 10 50
    fi
}

connect_server() {
    HOSTS=$(awk '/^Host[[:space:]]+/ {print $2}' "$CONFIG_FILE" | grep -v '\*')
    [ -z "$HOSTS" ] && { whiptail --msgbox "No hosts found in SSH config!" 10 50; return; }

    MENU_ITEMS=()
    for h in $HOSTS; do
        MENU_ITEMS+=("$h" "")
    done

    SELECTED_HOST=$(whiptail --title "Connect to Server" --menu "Select a host to connect:" 20 60 10 "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3) || return

    if [ -n "$SELECTED_HOST" ]; then
        whiptail --msgbox "Connecting to $SELECTED_HOST...\nUse Ctrl+D or 'exit' to return to menu" 10 60
        ssh "$SELECTED_HOST"
    fi
}

delete_host_config() {
    HOSTS=$(awk '/^Host[[:space:]]+/ {print $2}' "$CONFIG_FILE" | grep -v '\*')
    [ -z "$HOSTS" ] && { whiptail --msgbox "No hosts found in SSH config!" 10 50; return; }

    HOST_TO_DELETE=$(whiptail --title "Delete SSH Config Host" --menu "Select a host to delete:" 20 60 10 $(for h in $HOSTS; do echo "$h" "$h"; done) 3>&1 1>&2 2>&3) || return

    if (whiptail --yesno "Are you sure you want to delete host [$HOST_TO_DELETE] from SSH config?" 10 60); then
        cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%F_%T)" # backup
        awk -v host="$HOST_TO_DELETE" '
            BEGIN {skip=0}
            $1=="Host" && $2==host {skip=1; next}
            skip && $1=="Host" {skip=0}
            !skip {print}
        ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        whiptail --msgbox "🗑️ Host [$HOST_TO_DELETE] deleted from SSH config" 10 60
    fi
}

edit_config() {
    # Pick preferred editor: use $EDITOR env var, then fall back to common ones
    EDITOR_CMD="${EDITOR:-}"
    if [ -z "$EDITOR_CMD" ]; then
        for ed in nano vim vi; do
            if command -v "$ed" &>/dev/null; then
                EDITOR_CMD="$ed"
                break
            fi
        done
    fi

    if [ -z "$EDITOR_CMD" ]; then
        whiptail --msgbox "❌ No text editor found.\nPlease install nano or vim, or set the \$EDITOR environment variable." 10 60
        return
    fi

    # Show edit options submenu
    EDIT_ACTION=$(whiptail --title "✏️ Edit SSH Config" --menu "Choose an action:" 15 60 4 \
        "1" "Edit full config in $EDITOR_CMD" \
        "2" "Edit a specific host block" \
        "3" "View config (read-only)" 3>&1 1>&2 2>&3) || return

    case $EDIT_ACTION in
        1)
            # Backup before opening
            cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%F_%T)"
            # Drop back to terminal to open editor
            clear
            $EDITOR_CMD "$CONFIG_FILE"
            whiptail --msgbox "✅ Config saved. Backup created before editing." 10 60
            ;;
        2)
            HOSTS=$(awk '/^Host[[:space:]]+/ {print $2}' "$CONFIG_FILE" | grep -v '\*')
            [ -z "$HOSTS" ] && { whiptail --msgbox "No hosts found in SSH config!" 10 50; return; }

            SELECTED_HOST=$(whiptail --title "Select Host to Edit" --menu "Choose a host:" 20 60 10 \
                $(for h in $HOSTS; do echo "$h" "$h"; done) 3>&1 1>&2 2>&3) || return

            # Extract current field values from the host block
            CUR_HOSTNAME=$(awk -v host="$SELECTED_HOST" '
                /^Host[[:space:]]/ { in_block=($2==host); next }
                in_block && /^[[:space:]]*HostName[[:space:]]/ { print $2 }
            ' "$CONFIG_FILE")
            CUR_USER=$(awk -v host="$SELECTED_HOST" '
                /^Host[[:space:]]/ { in_block=($2==host); next }
                in_block && /^[[:space:]]*User[[:space:]]/ { print $2 }
            ' "$CONFIG_FILE")
            CUR_PORT=$(awk -v host="$SELECTED_HOST" '
                /^Host[[:space:]]/ { in_block=($2==host); next }
                in_block && /^[[:space:]]*Port[[:space:]]/ { print $2 }
            ' "$CONFIG_FILE")
            CUR_IDENTITY=$(awk -v host="$SELECTED_HOST" '
                /^Host[[:space:]]/ { in_block=($2==host); next }
                in_block && /^[[:space:]]*IdentityFile[[:space:]]/ { print $2 }
            ' "$CONFIG_FILE")

            # Default port to 22 if not set
            [ -z "$CUR_PORT" ] && CUR_PORT="22"

            # Prompt user to edit each field, pre-filled with current values
            NEW_ALIAS=$(whiptail --title "✏️ Edit Host: $SELECTED_HOST" \
                --inputbox "Host alias (shortcut name):" 10 60 "$SELECTED_HOST" 3>&1 1>&2 2>&3) || return
            NEW_HOSTNAME=$(whiptail --title "✏️ Edit Host: $SELECTED_HOST" \
                --inputbox "HostName (IP or domain):" 10 60 "$CUR_HOSTNAME" 3>&1 1>&2 2>&3) || return
            NEW_USER=$(whiptail --title "✏️ Edit Host: $SELECTED_HOST" \
                --inputbox "User (login username):" 10 60 "$CUR_USER" 3>&1 1>&2 2>&3) || return
            NEW_PORT=$(whiptail --title "✏️ Edit Host: $SELECTED_HOST" \
                --inputbox "Port:" 10 60 "$CUR_PORT" 3>&1 1>&2 2>&3) || return
            NEW_IDENTITY=$(whiptail --title "✏️ Edit Host: $SELECTED_HOST" \
                --inputbox "IdentityFile (full path to private key):" 10 60 "$CUR_IDENTITY" 3>&1 1>&2 2>&3) || return

            # Backup and rewrite config without the old host block
            cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%F_%T)"
            awk -v host="$SELECTED_HOST" '
                BEGIN { skip=0 }
                /^Host[[:space:]]/ && $2==host { skip=1; next }
                skip && /^Host[[:space:]]/ { skip=0 }
                !skip { print }
            ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"

            # Append the updated host block
            {
                echo ""
                echo "Host $NEW_ALIAS"
                echo "    HostName $NEW_HOSTNAME"
                echo "    User $NEW_USER"
                echo "    Port $NEW_PORT"
                [ -n "$NEW_IDENTITY" ] && echo "    IdentityFile $NEW_IDENTITY"
            } >> "$CONFIG_FILE.tmp"
            mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            chmod 600 "$CONFIG_FILE"

            whiptail --msgbox "✅ Host [$SELECTED_HOST] updated successfully.\nBackup created before editing." 10 60
            ;;
        3)
            # Read-only view
            CONFIG_CONTENT=$(cat "$CONFIG_FILE")
            if [ -z "$CONFIG_CONTENT" ]; then
                whiptail --msgbox "ℹ️ SSH config file is empty." 10 50
            else
                whiptail --title "📄 SSH Config (read-only)" --scrolltext \
                    --msgbox "$CONFIG_CONTENT" 30 80
            fi
            ;;
    esac
}

# --- Main Menu Loop ---
while true; do
    CHOICE=$(whiptail --title "🔑 SSH Key Manager" --menu "Choose an option:" 22 60 13 \
    "1"  "Connect to Server" \
    "2"  "Generate new SSH key" \
    "3"  "Copy key to server & update config" \
    "4"  "Test passwordless login" \
    "5"  "List existing keys" \
    "6"  "Edit SSH config file" \
    "7"  "Delete a key" \
    "8"  "Delete host from config" \
    "9"  "Show server history with status" \
    "10" "Exit" 3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && exit 0

    case $CHOICE in
        1)  connect_server ;;
        2)  generate_key ;;
        3)  copy_key ;;
        4)  test_login ;;
        5)  list_keys ;;
        6)  edit_config;;
        7)  delete_key ;;
        8)  delete_host_config ;;
        9)  list_history ;;
        10) exit 0 ;;
    esac
done
