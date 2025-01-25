#!/bin/bash

FILE_DIR=$( cd "$( dirname "$0" )" && pwd )/files

# Array of patterns for files that need to be copied instead of symlinked
COPY_PATTERNS=(
    "$HOME/.ssh/config.d/*.config"
)

# Array to track action items for user review
ACTION_ITEMS=()

# Print help message
function print_help {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h           Show this help message and exit."
    echo ""
    echo "Description:"
    echo "  This script sets up your environment by linking or copying shared configuration files."
    echo ""
    echo "Logging:"
    echo "  INFO: General operation logs."
    echo "  WARN: Warnings about potential issues."
    echo "  ERROR: Errors encountered during execution."
}

# Function to ensure environment variables are set
function ensure_variables {
    if [[ -z "$GIT_USER_NAME" ]]; then
        read -p "Enter your Git user name: " GIT_USER_NAME
    fi
    if [[ -z "$GIT_USER_EMAIL" ]]; then
        read -p "Enter your Git email: " GIT_USER_EMAIL
    fi
}

# Function to process template files
function process_templates {
    local template="$1"
    local dest="$2"

    # Ensure variables are set
    ensure_variables

    # Replace placeholders with actual values
    sed "s/{{GIT_USER_NAME}}/$GIT_USER_NAME/g; s/{{GIT_USER_EMAIL}}/$GIT_USER_EMAIL/g" "$template" > "$dest"
    echo "INFO: Processed template: $template -> $dest"
}

# Function to append content to ~/.ssh/config if necessary
function append_ssh_config {
    local ssh_config="$HOME/.ssh/config"
    local include_line="Include ~/.ssh/config.d/*.config"

    mkdir -p "$HOME/.ssh/config.d"

    if ! grep -Fxq "$include_line" "$ssh_config"; then
        echo "$include_line" >> "$ssh_config"
        echo "INFO: Appended Include line to $ssh_config"
    else
        echo "INFO: Include line already exists in $ssh_config"
    fi
}

# Function to validate filenames
function validate_filename {
    local filename="$1"
    if [[ "$filename" == "." ]] || [[ "$filename" == ".." ]] || [[ "$filename" == *~ ]]; then
        return 1
    fi
    if [[ "$filename" == *.disable ]] || [[ "$filename" == *.disabled ]]; then
        echo "INFO: Ignoring disabled symlink: $filename" >&2
        return 1
    fi
    return 0
}

# Function to check if a file should be copied
function should_copy {
    local filepath="$1"
    for pattern in "${COPY_PATTERNS[@]}"; do
        if [[ "$filepath" == $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Function to create symlinks or copy files
function make_links {
    local dest_folder="$1"
    local source_folder="$2"
    local use_sudo="${3:-}"

    if [[ ! -d "$source_folder" ]]; then
        echo "ERROR: Source folder '$source_folder' does not exist." >&2
        exit 1
    fi

    if [[ -n "$use_sudo" && "$use_sudo" != "sudo" ]]; then
        echo "ERROR: Invalid argument for sudo option: $use_sudo" >&2
        exit 1
    fi

    [[ "$use_sudo" == "sudo" ]] && SUDO="sudo" || SUDO=""

    find "$source_folder" -mindepth 1 -maxdepth 1 | while IFS= read -r source; do
        local file
        file=$(basename "$source")
        validate_filename "$file"
        if [[ $? -ne 0 ]]; then
            continue
        fi

        local dest="$dest_folder/$file"
        if [[ -d "$source" ]]; then
            $SUDO mkdir -p "$dest"
            make_links "$dest" "$source" "$use_sudo"
            continue
        fi

        # Determine whether to copy or symlink
        if should_copy "$dest"; then
            echo "INFO: Copying file: $source -> $dest" >&2
            $SUDO cp "$source" "$dest"
        else
            if [[ -e "$dest" ]]; then
                if cmp -s "$source" "$dest"; then
                    echo "INFO: Skipping identical file: $dest" >&2
                    continue
                else
                    echo "INFO: $dest exists, moving to $dest.old" >&2
                    $SUDO mv "$dest" "$dest.old"

                    # Add action item for user to review
                    ACTION_ITEMS+=("Review and merge: $dest and $dest.old")
                fi
            elif [[ -L "$dest" && ! -e "$dest" ]]; then
                echo "WARN: Deleting broken link: $dest --> $(readlink "$dest")" >&2
                $SUDO rm "$dest"
            fi

            echo "INFO: Creating symlink: $dest -> $source" >&2
            $SUDO ln -s "$source" "$dest"
        fi
    done
}

# Main script logic
if [[ $# -ge 1 ]]; then
    case "$1" in
        --help|-h)
            print_help
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            exit 1
            ;;
    esac
fi

if [[ ! -d "$FILE_DIR" ]]; then
    echo "ERROR: File directory '$FILE_DIR' does not exist." >&2
    exit 1
fi

make_links "$HOME" "$FILE_DIR/HOME"
make_links "/" "$FILE_DIR/ROOT" "sudo"

ensure_variables
append_ssh_config

# Print summary of action items
if [[ ${#ACTION_ITEMS[@]} -gt 0 ]]; then
    echo -e "\nSUMMARY OF ACTION ITEMS:"
    for item in "${ACTION_ITEMS[@]}"; do
        echo "  - $item"
    done
else
    echo -e "\nNo action items. All files were processed successfully."
fi
