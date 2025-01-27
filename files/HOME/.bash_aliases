# ========================================
# This file is part of the computerSetup package.
# Repository: https://github.com/ryandmorton/computerSetup
# ========================================

# User type configuration
# Uncomment the following line and set USER_TYPE to "developer" if you are a developer.
# Otherwise, leave it as "user" or set it to "user".
export USER_TYPE="developer"

# Developer/general aliases sourcing
USER_TYPE="${USER_TYPE:-user}"

# General aliases (always included)
if [ -f "$HOME/.bash_general_aliases" ]; then
    source "$HOME/.bash_general_aliases"
fi

# Developer-specific aliases (included if USER_TYPE is "developer")
if [ "$USER_TYPE" == "developer" ]; then
    if [ -f "$HOME/.bash_developer_aliases" ]; then
        source "$HOME/.bash_developer_aliases"
    fi
fi

# Include personalized aliases, if they exist
if [ -f "$HOME/.bash_personal_aliases" ]; then
    source "$HOME/.bash_personal_aliases"
fi
