#!/bin/bash

function show_help {
    echo "Usage: $(basename $0) -k <keyname> -s <server_login> [-c]"
    echo
    echo "Options:"
    echo "  -k <keyname>       Specify the SSH key name (e.g., ~/.ssh/id_rsa)."
    echo "  -s <server_login>  Specify the server login (e.g., user@server.com)."
    echo "  -c                 Add the SSH config block for the key (optional)."
    echo "  -h                 Show this help message and exit."
    echo
    echo "Example:"
    echo "  $(basename $0) -k ~/.ssh/my_key -s user@server.com -c"
    echo "    * Creates local SSH key files:"
    echo "        ~/.ssh/my_key"
    echo "        ~/.ssh/my_key.pub"
    echo "    * Adds the public key to the server to enable passwordless login."
    echo "    * Optionally updates ~/.ssh/config with the corresponding entry."
    exit 0
}

# Default values
KEY_NAME=""
SERVER_LOGIN=""
ADD_CONFIG=false

# Parse command-line arguments
while getopts "k:s:ch" opt; do
    case $opt in
        k) KEY_NAME="$OPTARG" ;;
        s) SERVER_LOGIN="$OPTARG" ;;
        c) ADD_CONFIG=true ;;
        h) show_help ;;
        *) echo "Invalid option: -$OPTARG" >&2; show_help ;;
    esac
done

# Validate required arguments
if [ -z "$KEY_NAME" ]; then
    echo "ERROR: Missing required option -k <keyname>"
    show_help
fi

if [ -z "$SERVER_LOGIN" ]; then
    echo "ERROR: Missing required option -s <server_login>"
    show_help
fi

PUB_KEY_NAME="${KEY_NAME}.pub"

# Check if the key already exists
if [ -e "$KEY_NAME" ]; then
    echo "Key $KEY_NAME already exists. Would you like to overwrite it? [y/N]"
    read -r resp
    if [[ "$resp" =~ ^[yY]$ ]]; then
        rm -f "$KEY_NAME" "$PUB_KEY_NAME"
        ssh-keygen -t rsa -N "" -f "$KEY_NAME"
    else
        echo "Using existing key: $KEY_NAME"
    fi
else
    # Generate new key if it doesn't exist
    echo "Generating new key: $KEY_NAME"
    ssh-keygen -t rsa -N "" -f "$KEY_NAME"
fi

# Add the public key to the server
echo "Adding the public key to the server: $SERVER_LOGIN"
cat "$PUB_KEY_NAME" | ssh "$SERVER_LOGIN" 'mkdir -p .ssh && chmod 700 .ssh && cat >> .ssh/authorized_keys'

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to add the public key to the server. Aborting."
    exit 1
fi

if [ "$ADD_CONFIG" = true ]; then
    echo "Would you like to add an SSH config block for this key? [y/N]"
    read -r config_resp
    if [[ "$config_resp" =~ ^[yY]$ ]]; then
        SSH_CONFIG="$HOME/.ssh/config"
        HOST_NAME="$(basename "$KEY_NAME")"
        HOST_ONLY="$(echo "$SERVER_LOGIN" | cut -d '@' -f 2)"

        echo "Adding the following block to $SSH_CONFIG:" \
            "\nHost $HOST_NAME\n    HostName $HOST_ONLY\n    IdentityFile $KEY_NAME\n    User $(echo "$SERVER_LOGIN" | cut -d '@' -f 1)\n"

        mkdir -p "$HOME/.ssh"
        touch "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"

        {
            echo ""
            echo ""
            echo "    Host $HOST_NAME"
            echo "    HostName $HOST_ONLY"
            echo "    IdentityFile $KEY_NAME"
            echo "    User $(echo "$SERVER_LOGIN" | cut -d '@' -f 1)"
        } >> "$SSH_CONFIG"

        echo "SSH config updated successfully."
    fi
fi

echo "Done! You should now be able to log in to $SERVER_LOGIN without a password."
