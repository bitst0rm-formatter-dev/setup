#!/usr/bin/env bash

# Define the repository owner
REPO_OWNER="bitst0rm-formatter-dev"

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Array of URLs to download
urls=(
    "https://github.com/$REPO_OWNER/astyle/releases/download/astyle-3.5-macos11/astyle-3.5-macos11.tar.gz"
    "https://github.com/$REPO_OWNER/clang-format/releases/download/clang-format-18.1.8-macos11/clang-format-18.1.8-macos11.tar.gz"
    "https://github.com/$REPO_OWNER/erlang/releases/download/erlang-macos11/erlang-27.0-macos11.tar.gz"
    "https://github.com/$REPO_OWNER/erlang/releases/download/dependencies-macos11/libxslt-v1.1.41-macos11.tar.gz"
    "https://github.com/$REPO_OWNER/erlang/releases/download/dependencies-macos11/openssl-3.3.1-macos11.tar.gz"
    "https://github.com/$REPO_OWNER/erlang/releases/download/dependencies-macos11/unixodbc-2.3.12-macos11.tar.gz"
    "https://github.com/$REPO_OWNER/erlang/releases/download/dependencies-macos11/wxwidgets-3.2.5-macos11.tar.gz"
    "https://github.com/$REPO_OWNER/ruby/releases/download/ruby-macos11/ruby-3.3.3-macos11.tar.gz"
    "https://github.com/$REPO_OWNER/ruby/releases/download/dependencies-macos11/readline-8.2-macos11.tar.gz"
    "https://github.com/$REPO_OWNER/ruby/releases/download/dependencies-macos11/yaml-0.2.5-macos11.tar.gz"
    "https://github.com/$REPO_OWNER/ruby/releases/download/dependencies-macos11/zlib-1.3.1-macos11.tar.gz"
    "https://github.com/$REPO_OWNER/uncrustify/releases/download/uncrustify-0.79.0-macos11/uncrustify-0.79.0-macos11.tar.gz"
    "https://nodejs.org/dist/v22.3.0/node-v22.3.0-darwin-x64.tar.gz"
    "https://julialang-s3.julialang.org/bin/mac/x64/1.10/julia-1.10.4-mac64.tar.gz"
)

# Function to validate URL
validate_urls() {
    for url in "${urls[@]}"; do
        if ! curl --silent --fail --location -r 0-0 --output /dev/null "$url"; then
            handle_error "Invalid URL: $url"
        fi
    done
}

# Function to download and extract files
download_and_extract() {
    local url="$1"
    local tarfile=$(basename "$url")
    local tempdir=$(mktemp -d)

    # Download file
    curl -sSL "$url" -o "$tempdir/$tarfile" || handle_error "Failed to download $url"

    # Extract file
    tar -xzf "$tempdir/$tarfile" -C "$tempdir" || handle_error "Failed to extract $tarfile"

    # Determine directory name
    local extracted_dir=$(tar -tzf "$tempdir/$tarfile" | head -n 1 | sed -e 's@/.*@@')
    local dirname=$(echo "$tarfile" | sed -n 's/\(.*\)-v\?\([0-9.]\+\).*/\1@\2/p')

    # Check if extracted_dir and dirname are different before attempting to rename
    if [[ "$tempdir/$extracted_dir" != "$tempdir/$dirname" ]]; then
        mv "$tempdir/$extracted_dir" "$tempdir/$dirname" || handle_error "Failed to rename $extracted_dir to $dirname"
    fi

    # Move extracted directories to 'work'
    if [[ -d "$tempdir/$dirname/usr/local/work" ]]; then
        mv "$tempdir/$dirname"/usr/local/work/* work/ || handle_error "Failed to move $dirname to work"
    else
        mv "$tempdir/$dirname" work/ || handle_error "Failed to move $dirname to work"
    fi

    # Clean up
    rm -rf "$tempdir" || handle_error "Failed to delete temporary directory $tempdir"
}

# Validate URLs before proceeding
validate_urls

# Delete existing symbolic link if it exists
if [ -L /usr/local/work ]; then
    sudo rm -f /usr/local/work || handle_error "Failed to delete existing symbolic link"
fi

# Delete current 'work' directory if it exists
if [ -d work ]; then
    rm -rf work || handle_error "Failed to delete current 'work' directory"
fi

# Create 'work' directory if it doesn't exist
mkdir -p work || handle_error "Failed to create 'work' directory"

# Download and extract each URL
for url in "${urls[@]}"; do
    download_and_extract "$url"
done

# Move work to /usr/local/work
sudo mv "$(pwd)/work" /usr/local/work

# Determine shell configuration file
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_FILE="$HOME/.zshrc"
else
    SHELL_FILE="$HOME/.bashrc"
fi

# Backup existing configuration file
# cp "$SHELL_FILE" "$SHELL_FILE.bak" || handle_error "Failed to backup $SHELL_FILE"

# Update shell configuration file
if ! grep -q '###### WORK BEGIN ######' "$SHELL_FILE"; then
    echo "" >> "$SHELL_FILE" || handle_error "Failed to update $SHELL_FILE"
fi

# Remove old block if it exists
sed -i '/###### WORK BEGIN ######/,/###### WORK END ######/d' "$SHELL_FILE"

# Append environment variables to block
{
    echo "###### WORK BEGIN ######"
    for dir in /usr/local/work/*; do
        if [ -d "$dir/bin" ]; then
            echo "export PATH=\"$dir/bin:\$PATH\""
        fi
        if [ -d "$dir/lib" ]; then
            echo "export LD_LIBRARY_PATH=\"$dir/lib:\$LD_LIBRARY_PATH\""
        fi
        if [ -d "$dir/include" ]; then
            echo "export CPATH=\"$dir/include:\$CPATH\""
        fi
        if [ -d "$dir/share" ]; then
            echo "export XDG_DATA_DIRS=\"$dir/share:\$XDG_DATA_DIRS\""
        fi
        if [[ "$dir" == *openssl* ]]; then
            echo "export SSL_CERT_DIR=\"$dir/ssl\""
        fi
    done
    echo "###### WORK END ######"
} >> "$SHELL_FILE" || handle_error "Failed to update $SHELL_FILE"

# Source shell configuration file
source "$SHELL_FILE" || handle_error "Failed to source $SHELL_FILE"

# Script completed successfully
echo "Script completed successfully."
