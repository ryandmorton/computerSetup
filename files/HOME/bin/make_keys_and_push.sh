#!/bin/bash

function show_help {
    echo "Usage: $(basename $0) -k <keyname> -s <server_login>"
    echo
    echo "Options:"
    echo "  -k <keyname>       Specify the SSH key name (e.g., ~/.ssh/id_rsa)."
    echo "  -s <server_login>  Specify the server login (e.g., user@server.com)."
    echo "  -h                 Show this help message and exit."
    echo
    echo "Example:"
    echo "  $(basename $0) -k ~/.ssh/my_key -s user@server.com"
    echo "    * Creates local SSH key files:"
    echo "        ~/.ssh/my_key"
    echo "        ~/.ssh/my_key.pub"
    echo "    * Adds the public key to the server to enable passwordless login."
    exit 0
}

# Default values
KEY_NAME=""
SERVER_LOGIN=""

# Parse command-line arguments
while getopts "k:s:u:h" opt; do
    case $opt in
        k) KEY_NAME="$OPTARG" ;;
        s|u) SERVER_LOGIN="$OPTARG" ;;
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

echo "Done! You should now be able to log in to $SERVER_LOGIN without a password."
