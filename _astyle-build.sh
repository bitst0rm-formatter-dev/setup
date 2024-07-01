#!/usr/bin/env bash

# Set AStyle versions
ASTYLE_VERSIONS=("3.5")

# Set base directory and OS version (allow overriding via environment variables)
BASE_DIR="${BASE_DIR:-/usr/local/work}"
OS_VERSION="${OS_VERSION:-macos11}"

# Ensure script fails on errors
set -euo pipefail

# Function to download and build AStyle
build_astyle() {
    local astyle_version=$1

    # Download the archive
    if ! curl -LO "https://netcologne.dl.sourceforge.net/project/astyle/astyle/astyle%20${astyle_version}/astyle-${astyle_version}.tar.bz2"; then
        echo "Failed to download https://netcologne.dl.sourceforge.net/project/astyle/astyle/astyle%20${astyle_version}/astyle-${astyle_version}.tar.bz2"
        exit 1
    fi

    tar -xjf "astyle-${astyle_version}.tar.bz2"

    # Build AStyle
    cd "astyle-${astyle_version}/build/mac"
    make prefix="${BASE_DIR}/astyle@${astyle_version}"
    make install prefix="${BASE_DIR}/astyle@${astyle_version}"
    cd ../../..
}

# Function to verify AStyle installation
verify_astyle() {
    local astyle_version=$1
    "${BASE_DIR}/astyle@${astyle_version}/bin/astyle" --version
}

# Function to package AStyle
package_astyle() {
    local astyle_version=$1
    tar -czvf "astyle-${astyle_version}-${OS_VERSION}.tar.gz" \
        -s "|^${BASE_DIR}/|astyle-${astyle_version}-${OS_VERSION}/|" \
        "${BASE_DIR}/astyle@${astyle_version}"/*
}

# Loop through each version of AStyle
for version in "${ASTYLE_VERSIONS[@]}"; do
    build_astyle "$version"
    verify_astyle "$version"
    package_astyle "$version"
done

# Cleanup
rm -rf "${BASE_DIR}"/*
