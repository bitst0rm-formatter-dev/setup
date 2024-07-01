#!/usr/bin/env bash

# Set Uncrustify versions
UNCRUSTIFY_VERSIONS=("0.79.0")

# Set base directory and OS version (allow overriding via environment variables)
BASE_DIR="${BASE_DIR:-/usr/local/work}"
OS_VERSION="${OS_VERSION:-macos11}"

# Ensure script fails on errors
set -euo pipefail

# Function to download and build Uncrustify
build_uncrustify() {
    local uncrustify_version=$1

    # Download the archive
    if ! curl -LO "https://github.com/uncrustify/uncrustify/releases/download/uncrustify-${uncrustify_version}/uncrustify-${uncrustify_version}.tar.gz"; then
        echo "Failed to download https://github.com/uncrustify/uncrustify/releases/download/uncrustify-${uncrustify_version}/uncrustify-${uncrustify_version}.tar.gz"
        exit 1
    fi

    tar -xzf "uncrustify-${uncrustify_version}.tar.gz"

    # Build Uncrustify
    cd "uncrustify-${uncrustify_version}"
    mkdir -p build
    cd build
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="${BASE_DIR}/uncrustify@${uncrustify_version}" \
        -DCMAKE_BUILD_TYPE=Release \
        -G Ninja
    ninja
    ninja install
    cd ../..
}

# Function to verify Uncrustify installation
verify_uncrustify() {
    local uncrustify_version=$1
    "${BASE_DIR}/uncrustify@${uncrustify_version}/bin/uncrustify" --version
}

# Function to package Uncrustify
package_uncrustify() {
    local uncrustify_version=$1
    tar -czvf "uncrustify-${uncrustify_version}-${OS_VERSION}.tar.gz" \
        -s "|^${BASE_DIR}/|uncrustify-${uncrustify_version}-${OS_VERSION}/|" \
        "${BASE_DIR}/uncrustify@${uncrustify_version}"/*
}

# Loop through each version of Uncrustify
for version in "${UNCRUSTIFY_VERSIONS[@]}"; do
    build_uncrustify "$version"
    verify_uncrustify "$version"
    package_uncrustify "$version"
done

# Cleanup
rm -rf "${BASE_DIR}"/*
