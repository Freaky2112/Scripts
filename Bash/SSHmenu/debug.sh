#!/bin/bash
CONFIG_FILE="$HOME/.ssh/config"

HOSTS=$(grep -E '^[[:space:]]*Host[[:space:]]+' "$CONFIG_FILE" \
    | sed -E 's/^[[:space:]]*Host[[:space:]]+//' \
    | grep -v '^\*')

HOST_ARRAY=($HOSTS)

for h in "${HOST_ARRAY[@]}"; do
    echo "[$h]"
done