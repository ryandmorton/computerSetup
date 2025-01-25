#!/bin/bash

FILE_DIR=$( cd "$( dirname "$0" )" && pwd )/files

# Array of patterns for files that need to be copied instead of symlinked
COPY_PATTERNS=(
    "$HOME/.ssh/config.d/*.config"
)

# Array to track action items for user review
NON_SUDO_ACTION_ITEMS=()
SUDO_ACTION_ITEMS=()

# Default options
MERGE_ENABLED=false
MERGE_TOOL="vimdiff"
LOG_FILE=""
DRY_RUN=false

# Print help message
function print_help {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h           Show this help message and exit."
    echo "  --merge, -m          Automatically attempt to merge conflicting files."
    echo "  --merge-tool <tool>  Specify merge tool (vimdiff, emacs, git-style). Default: vimdiff."
    echo "  --log-file <file>    Save logs to the specified file."
    echo "  --dry-run            Simulate actions without making any changes."
    echo ""
    echo "Description:"
    echo "  This script sets up your environment by linking or copying shared configuration files."
    echo ""
    echo "Logging:"
    echo "  INFO: General operation logs."
    echo "  WARN: Warnings about potential issues."
    echo "  ERROR: Errors encountered during execution."
}

# Log function to handle logging to a file if specified
function log {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$level] $message" >> "$LOG_FILE"
    fi
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
    log "INFO" "Processed template: $template -> $dest"
}

# Function to append content to ~/.ssh/config if necessary
function append_ssh_config {
    local ssh_config="$HOME/.ssh/config"
    local include_line="Include ~/.ssh/config.d/*.config"

    mkdir -p "$HOME/.ssh/config.d"

    if ! grep -Fxq "$include_line" "$ssh_config"; then
        echo "$include_line" >> "$ssh_config"
        log "INFO" "Appended Include line to $ssh_config"
    else
        log "INFO" "Include line already exists in $ssh_config"
    fi
}

# Function to validate filenames
function validate_filename {
    local filename="$1"
    if [[ "$filename" == "." ]] || [[ "$filename" == ".." ]] || [[ "$filename" == *~ ]]; then
        return 1
    fi
    if [[ "$filename" == *.disable ]] || [[ "$filename" == *.disabled ]]; then
        log "INFO" "Ignoring disabled symlink: $filename"
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

# Function to interactively merge files
function interactive_merge {
    local file1="$1"
    local file2="$2"
    local use_sudo="$3"

    log "INFO" "Starting merge for $file1 and $file2"
    case "$MERGE_TOOL" in
        vimdiff)
            if [[ "$use_sudo" == "sudo" ]]; then
                sudo vimdiff "$file1" "$file2"
            else
                vimdiff "$file1" "$file2"
            fi
            ;;
        emacs)
            if [[ "$use_sudo" == "sudo" ]]; then
                sudo emacsclient -c -e "(ediff-files \"$file1\" \"$file2\")"
            else
                emacsclient -c -e "(ediff-files \"$file1\" \"$file2\")"
            fi
            ;;
        git-style)
            local merged_file="$file1.new"
            if [[ "$use_sudo" == "sudo" ]]; then
                sudo diff3 -m "$file1" "$file2" > "$merged_file" || {
                    log "INFO" "Conflict detected. Edit $merged_file to resolve."
                }
            else
                diff3 -m "$file1" "$file2" > "$merged_file" || {
                    log "INFO" "Conflict detected. Edit $merged_file to resolve."
                }
            fi
            ;;
        *)
            log "ERROR" "Unknown merge tool: $MERGE_TOOL"
            exit 1
            ;;
    esac
    log "INFO" "Merge completed. Review $file1 for final changes."
}

# Function to create symlinks or copy files
function make_links {
    local dest_folder="$1"
    local source_folder="$2"
    local use_sudo="${3:-}"

    if [[ ! -d "$source_folder" ]]; then
        log "ERROR" "Source folder '$source_folder' does not exist."
        exit 1
    fi

    if [[ -n "$use_sudo" && "$use_sudo" != "sudo" ]]; then
        log "ERROR" "Invalid argument for sudo option: $use_sudo"
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
            if [[ "$DRY_RUN" == true ]]; then
                log "INFO" "[Dry-run] Would create directory: $dest"
            else
                $SUDO mkdir -p "$dest"
            fi
            make_links "$dest" "$source" "$use_sudo"
            continue
        fi

        # Determine whether to copy or symlink
        if should_copy "$dest"; then
            if [[ "$DRY_RUN" == true ]]; then
                log "INFO" "[Dry-run] Would copy file: $source -> $dest"
            else
                log "INFO" "Copying file: $source -> $dest"
                $SUDO cp "$source" "$dest"
            fi
        else
            if [[ -e "$dest" ]]; then
                if cmp -s "$source" "$dest"; then
                    log "INFO" "Skipping identical file: $dest"
                    continue
                else
                    if [[ "$DRY_RUN" == true ]]; then
                        log "INFO" "[Dry-run] Would move existing file: $dest -> $dest.old"
                    else
                        log "INFO" "$dest exists, moving to $dest.old"
                        $SUDO mv "$dest" "$dest.old"

                        if [[ "$use_sudo" == "sudo" ]]; then
                            SUDO_ACTION_ITEMS+=("Review and merge: $dest and $dest.old")
                        else
                            NON_SUDO_ACTION_ITEMS+=("Review and merge: $dest and $dest.old")
                        fi
                    fi
                fi
            elif [[ -L "$dest" && ! -e "$dest" ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    log "INFO" "[Dry-run] Would delete broken link: $dest"
                else
                    log "WARN" "Deleting broken link: $dest --> $(readlink "$dest")"
                    $SUDO rm "$dest"
                fi
            fi

            if [[ "$DRY_RUN" == true ]]; then
                log "INFO" "[Dry-run] Would create symlink: $dest -> $source"
            else
                log "INFO" "Creating symlink: $dest -> $source"
                $SUDO ln -s "$source" "$dest"
            fi
        fi
    done
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            print_help
            exit 0
            ;;
        --merge|-m)
            MERGE_ENABLED=true
            shift
            ;;
        --merge-tool)
            MERGE_TOOL="$2"
            shift 2
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ ! -d "$FILE_DIR" ]]; then
    log "ERROR" "File directory '$FILE_DIR' does not exist."
    exit 1
fi

make_links "$HOME" "$FILE_DIR/HOME"
make_links "/" "$FILE_DIR/ROOT" "sudo"

ensure_variables
append_ssh_config

# Print summary of action items
if [[ ${#NON_SUDO_ACTION_ITEMS[@]} -gt 0 ]]; then
    echo -e "\nSUMMARY OF NON-SUDO ACTION ITEMS:"
    for item in "${NON_SUDO_ACTION_ITEMS[@]}"; do
        echo "  - $item"
    done
fi

if [[ ${#SUDO_ACTION_ITEMS[@]} -gt 0 ]]; then
    echo -e "\nSUMMARY OF SUDO ACTION ITEMS:"
    for item in "${SUDO_ACTION_ITEMS[@]}"; do
        echo "  - $item"
    done

    echo -e "\nWould you like to proceed with sudo merges? [y/N]"
    read -r sudo_merge_resp
    if [[ "$sudo_merge_resp" =~ ^[yY]$ ]]; then
        for item in "${SUDO_ACTION_ITEMS[@]}"; do
            file1=$(echo "$item" | awk -F ' and ' '{print $2}')
            file2=$(echo "$item" | awk -F ' and ' '{print $3}')
            interactive_merge "$file1" "$file2" "sudo"
        done
    else
        log "INFO" "Skipping sudo merges."
    fi
fi

if [[ ${#NON_SUDO_ACTION_ITEMS[@]} -gt 0 ]]; then
    echo -e "\nWould you like to proceed with non-sudo merges? [y/N]"
    read -r non_sudo_merge_resp
    if [[ "$non_sudo_merge_resp" =~ ^[yY]$ ]]; then
        for item in "${NON_SUDO_ACTION_ITEMS[@]}"; do
            file1=$(echo "$item" | awk -F ' and ' '{print $2}')
            file2=$(echo "$item" | awk -F ' and ' '{print $3}')
            interactive_merge "$file1" "$file2" ""
        done
    else
        log "INFO" "Skipping non-sudo merges."
    fi
fi

if [[ ${#NON_SUDO_ACTION_ITEMS[@]} -eq 0 && ${#SUDO_ACTION_ITEMS[@]} -eq 0 ]]; then
    echo -e "\nNo action items. All files were processed successfully."
fi

