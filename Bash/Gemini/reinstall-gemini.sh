#!/usr/bin/env bash
# Script to reinstall the Gemini CLI

set -euo pipefail

echo "🖥️➖ Removing old installation..."
sudo rm -rf /usr/local/lib/node_modules/@google/gemini-cli

echo "🧠💨 Clearing npm cache..."
sudo npm cache clean --force

echo "⚙️⬇️ Installing latest Gemini CLI..."
sudo npm install -g @google/gemini-cli@latest

echo "⚙️✅ Verifying installation..."
gemini --version