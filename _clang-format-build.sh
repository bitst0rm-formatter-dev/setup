#!/usr/bin/env bash

# Set Clang-Format versions
CLANG_VERSIONS=("18.1.8")

# Set base directory and OS version (allow overriding via environment variables)
BASE_DIR="${BASE_DIR:-/usr/local/work}"
OS_VERSION="${OS_VERSION:-macos11}"

# Ensure script fails on errors
set -euo pipefail

# Function to download and build Clang-Format
build_clang_format() {
    local clang_version=$1

    # Download the archive
    if ! curl -LO "https://github.com/llvm/llvm-project/releases/download/llvmorg-${clang_version}/llvm-project-${clang_version}.src.tar.xz"; then
        echo "Failed to download https://github.com/llvm/llvm-project/releases/download/llvmorg-${clang_version}/llvm-project-${clang_version}.src.tar.xz"
        exit 1
    fi

    tar -xJf "llvm-project-${clang_version}.src.tar.xz"

    # Build Clang-Format
    cd "llvm-project-${clang_version}.src"
    mkdir build
    cd build
    cmake ../llvm \
        -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" \
        -DCMAKE_INSTALL_PREFIX="${BASE_DIR}/clang-format@${clang_version}" \
        -DCMAKE_BUILD_TYPE=Release \
        -G Ninja
    ninja clang-format
    ninja install-clang-format
    cd ../..
}

# Function to verify Clang-Format installation
verify_clang_format() {
    local clang_version=$1
    "${BASE_DIR}/clang-format@${clang_version}/bin/clang-format" --version
}

# Function to package Clang-Format
package_clang_format() {
    local clang_version=$1
    tar -czvf "clang-format-${clang_version}-${OS_VERSION}.tar.gz" \
        -s "|^${BASE_DIR}/|clang-format-${clang_version}-${OS_VERSION}/|" \
        "${BASE_DIR}/clang-format@${clang_version}"/*
}

# Loop through each version of Clang-Format
for version in "${CLANG_VERSIONS[@]}"; do
    build_clang_format "$version"
    verify_clang_format "$version"
    package_clang_format "$version"
done

# Cleanup
rm -rf "${BASE_DIR}"/*
