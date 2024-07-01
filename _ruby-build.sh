#!/usr/bin/env bash

# Set versions
OPENSSL_VERSION="3.3.1"
READLINE_VERSION="8.2"
LIBYAML_VERSION="0.2.5"
ZLIB_VERSION="1.3.1"
RUBY_VERSIONS=("3.3.3")

# Set base directory and OS version (allow overriding via environment variables)
BASE_DIR="${BASE_DIR:-/usr/local/work}"
OS_VERSION="${OS_VERSION:-macos11}"

# Ensure script fails on errors
set -euo pipefail

# Directory setup
mkdir -p "${BASE_DIR}"/{openssl,readline,yaml,zlib}
for version in "${RUBY_VERSIONS[@]}"; do
    mkdir -p "${BASE_DIR}"/ruby@"${version}"
done

# Function to build and package dependencies
build_and_package() {
    local url="$1"
    local extra_cmd="$2"
    local prefix="$3"
    local extra_args="$4"
    local export_cmd="$5"

    local archive_name=$(basename "$url")
    local unpacked_name="${archive_name%.*.*}"

    curl -LO "$url" || { echo "Failed to download $url"; exit 1; }
    tar -xf "$archive_name" || { echo "Failed to extract $archive_name"; exit 1; }
    if [ ! -d "$unpacked_name" ]; then
        echo "Error: Directory $unpacked_name not found after extraction."
        exit 1
    fi

    cd "$unpacked_name"
    "$extra_cmd"
    if [ -n "$extra_args" ]; then
        ./configure --prefix="$prefix" "$extra_args"
    else
        ./configure --prefix="$prefix"
    fi
    make
    make install
    eval "$export_cmd"
    cd ..
    tar -czvf "${unpacked_name}-${OS_VERSION}.tar.gz" -s "|^/|${unpacked_name}-${OS_VERSION}/|" $prefix/* || { echo "Failed to create tarball."; exit 1; }
    rm -rf "$unpacked_name" "$archive_name"
}

# Dependencies to build and package
dep=(
    "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" ":" "${BASE_DIR}/openssl" "" "export PATH=${BASE_DIR}/openssl/bin:\$PATH; export LD_LIBRARY_PATH=${BASE_DIR}/openssl/lib:\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
    "https://ftp.gnu.org/gnu/readline/readline-${READLINE_VERSION}.tar.gz" ":" "${BASE_DIR}/readline" "--with-curses" "export PATH=${BASE_DIR}/readline/bin:\$PATH; export LD_LIBRARY_PATH=${BASE_DIR}/readline/lib:\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
    "https://github.com/yaml/libyaml/releases/download/${LIBYAML_VERSION}/yaml-${LIBYAML_VERSION}.tar.gz" ":" "${BASE_DIR}/yaml" "" "export PATH=${BASE_DIR}/yaml/bin:\$PATH; export LD_LIBRARY_PATH=${BASE_DIR}/yaml/lib:\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
    "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz" ":" "${BASE_DIR}/zlib" "" "export PATH=${BASE_DIR}/zlib/bin:\$PATH; export LD_LIBRARY_PATH=${BASE_DIR}/zlib/lib:\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
)

# Build and package dependencies
for (( i=0; i<${#dep[@]}; i+=5 )); do
    build_and_package "${dep[i]}" "${dep[i+1]}" "${dep[i+2]}" "${dep[i+3]}" "${dep[i+4]}"
done

# Function to build Ruby versions
build_ruby() {
    local version="$1"
    local url="$2"
    local prefix="$3"

    local archive_name=$(basename "$url")
    local unpacked_name="${archive_name%.*.*}"

    curl -LO "$url" || { echo "Failed to download $url"; exit 1; }
    tar -xf "$archive_name" || { echo "Failed to extract $archive_name"; exit 1; }
    if [ ! -d "$unpacked_name" ]; then
        echo "Error: Directory $unpacked_name not found after extraction."
        exit 1
    fi

    cd "$unpacked_name"

    args=(
        --disable-debug
        --disable-silent-rules
        --prefix="$prefix"
        --enable-shared
        --with-openssl-dir=${BASE_DIR}/openssl
        --with-readline-dir=${BASE_DIR}/readline
        --with-libyaml-dir=${BASE_DIR}/yaml
        --with-zlib-dir=${BASE_DIR}/zlib
    )

    ./autogen.sh
    ./configure "${args[@]}"
    make
    make install
    cd ..
    tar -czvf "ruby-${version}-${OS_VERSION}.tar.gz" -s "|^${prefix}|ruby-${version}-${OS_VERSION}/|" "$prefix"/* || { echo "Failed to create tarball."; exit 1; }
    rm -rf "$unpacked_name" "$archive_name"
}

# Build Ruby versions
for version in "${RUBY_VERSIONS[@]}"; do
    build_ruby \
        "$version" \
        "https://cache.ruby-lang.org/pub/ruby/${version:0:3}/ruby-${version}.tar.gz" \
        "${BASE_DIR}/ruby@${version}"
done

# Verify Ruby versions
for version in "${RUBY_VERSIONS[@]}"; do
    "${BASE_DIR}/ruby@${version}/bin/ruby" --version
done

# Cleanup
rm -rf "${BASE_DIR}"/*
