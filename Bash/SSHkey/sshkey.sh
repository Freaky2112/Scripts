#!/bin/bash
# create_sshkey.sh
# A script to generate SSH keys and (optionally) copy them to a server.

KEY_DIR="$HOME/.ssh"
DEFAULT_KEY_NAME="id_rsa_custom"
KEY_PATH="$KEY_DIR/$DEFAULT_KEY_NAME"

echo "🔑 SSH Key Generator"
echo "--------------------"

# Ask for key name
read -p "Enter key name (default: $DEFAULT_KEY_NAME): " KEY_NAME
KEY_NAME=${KEY_NAME:-$DEFAULT_KEY_NAME}
KEY_PATH="$KEY_DIR/$KEY_NAME"

# Ask for email
read -p "Enter your email (for key comment): " EMAIL

# Create key directory if not exists
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

# Generate the SSH key
if [ -f "$KEY_PATH" ]; then
    echo "⚠️ Key already exists at $KEY_PATH"
else
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH"
    echo "✅ Key generated at $KEY_PATH"
fi

# Ask to copy key to a remote server
read -p "Do you want to copy the key to a server? (y/n): " COPY_KEY

if [[ "$COPY_KEY" =~ ^[Yy]$ ]]; then
    read -p "Enter username@hostname: " REMOTE
    ssh-copy-id -i "$KEY_PATH.pub" "$REMOTE"
    echo "✅ Key copied to $REMOTE"
fi

echo "🎉 All done!"
