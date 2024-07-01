#!/usr/bin/env bash

# Define an associative array for versions
declare -A VERSIONS=(
    ["RUNNER"]="2.317.0"
    ["HASKELL"]="0.1.22.0"
    ["JULIA"]="1.10.4"
    ["NODE"]="22.3.0"
    ["PYTHON"]="3.12.4 3.8.10"
    ["R"]="4.4.1"
    ["REBAR3"]="3.23.0"
    ["RUST"]="1.79.0"
    ["RUSTFMT"]="1.5.1"
)

# Ensure script fails on errors
set -euo pipefail

mkdir -p "download"
cd download

# Function to download versions
download_version() {
    local type="$1"
    local version="$2"

    case "$type" in
        "RUNNER")
            curl -LO "https://github.com/actions/runner/releases/download/v${version}/actions-runner-osx-x64-${version}.tar.gz" || {
                echo "Failed to download Haskell version $version"
                exit 1
            }
            ;;
        "HASKELL")
            curl -LO "https://github.com/haskell/ghcup-hs/releases/download/v${version}/x86_64-apple-darwin-ghcup-${version}" || {
                echo "Failed to download Haskell version $version"
                exit 1
            }
            ;;
        "JULIA")
            curl -LO "https://julialang-s3.julialang.org/bin/mac/x64/1.10/julia-${version}-mac64.tar.gz" || {
                echo "Failed to download Julia version $version"
                exit 1
            }
            ;;
        "NODE")
            curl -LO "https://nodejs.org/dist/v${version}/node-v${version}-darwin-x64.tar.gz" || {
                echo "Failed to download Node.js version $version"
                exit 1
            }
            ;;
        "PYTHON")
            curl -LO "https://www.python.org/ftp/python/${version}/python-${version}-macos11.pkg" || {
                echo "Failed to download Python version $version"
                exit 1
            }
            ;;
        "R")
            curl -LO "https://cloud.r-project.org/bin/macosx/big-sur-x86_64/base/R-${version}-x86_64.pkg" || {
                echo "Failed to download R version $version"
                exit 1
            }
            ;;
        "REBAR3")
            curl -LO "https://github.com/erlang/rebar3/releases/download/${version}/rebar3" || {
                echo "Failed to download rebar3 version $version"
                exit 1
            }
            ;;
        "RUST")
            curl -LO "https://static.rust-lang.org/dist/rust-${version}-x86_64-apple-darwin.pkg" || {
                echo "Failed to download Rust version $version"
                exit 1
            }
            ;;
        "RUSTFMT")
            curl -LO "https://github.com/rust-lang/rustfmt/releases/download/v${version}/rustfmt_macos-x86_64_v${version}.tar.gz" || {
                echo "Failed to download rustfmt version $version"
                exit 1
            }
            ;;
        *)
            echo "Unknown type: $type"
            exit 1
            ;;
    esac
}

# Loop through each type/version pair and download
for type in "${!VERSIONS[@]}"; do
    versions="${VERSIONS[$type]}"
    for version in $versions; do
        download_version "$type" "$version"
    done
done

cd ..
