#!/usr/bin/env bash

# Set versions
OPENSSL_VERSION="3.3.1"
UNIXODBC_VERSION="2.3.12"
WXWIDGETS_VERSION="3.2.5"
LIBXSLT_VERSION="1.1.41"
ERLANG_VERSIONS=("27.0" "24.3.4.17")

# Set base directory and OS version (allow overriding via environment variables)
BASE_DIR="${BASE_DIR:-/usr/local/work}"
OS_VERSION="${OS_VERSION:-macos11}"

# Ensure script fails on errors
set -euo pipefail

# Directory setup
mkdir -p "${BASE_DIR}"/{openssl,unixodbc,wxwidgets,libxslt}
for version in "${ERLANG_VERSIONS[@]}"; do
    mkdir -p "${BASE_DIR}"/erlang@"${version}"
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
    "https://www.unixodbc.org/unixODBC-${UNIXODBC_VERSION}.tar.gz" ":" "${BASE_DIR}/unixodbc" "" "export PATH=${BASE_DIR}/unixodbc/bin:\$PATH; export LD_LIBRARY_PATH=${BASE_DIR}/unixodbc/lib:\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
    "https://github.com/wxWidgets/wxWidgets/releases/download/v${WXWIDGETS_VERSION}/wxWidgets-${WXWIDGETS_VERSION}.tar.bz2" ":" "${BASE_DIR}/wxwidgets" "" "export PATH=${BASE_DIR}/wxwidgets/bin:\$PATH; export LD_LIBRARY_PATH=${BASE_DIR}/wxwidgets/lib:\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
    "https://gitlab.gnome.org/GNOME/libxslt/-/archive/v${LIBXSLT_VERSION}/libxslt-v${LIBXSLT_VERSION}.tar.gz" "./autogen.sh" "${BASE_DIR}/libxslt" "PYTHON=/usr/local/opt/python3/bin/python3" "export PATH=${BASE_DIR}/libxslt/bin:\$PATH; export LD_LIBRARY_PATH=${BASE_DIR}/libxslt/lib:\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
)

# Build and package dependencies
for (( i=0; i<${#dep[@]}; i+=5 )); do
    build_and_package "${dep[i]}" "${dep[i+1]}" "${dep[i+2]}" "${dep[i+3]}" "${dep[i+4]}"
done

# Function to build Erlang versions
build_erlang() {
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
    ./otp_build autoconf

    args=(
        --disable-debug
        --disable-silent-rules
        --prefix="$prefix"
        --enable-dynamic-ssl-lib
        --enable-hipe
        --enable-shared-zlib
        --enable-smp-support
        --enable-threads
        --enable-wx
        --with-odbc="${BASE_DIR}/unixodbc"
        --with-ssl="${BASE_DIR}/openssl"
        --without-javac
    )

    if [[ "$(uname)" == "Darwin" ]]; then
        args+=(
            --enable-darwin-64bit
            --enable-kernel-poll
            --with-dynamic-trace=dtrace
        )
    fi

    ./configure "${args[@]}"
    make
    make install
    cd ..
    tar -czvf "erlang-${version}-${OS_VERSION}.tar.gz" -s "|^${prefix}|erlang-${version}-${OS_VERSION}/|" "$prefix"/* || { echo "Failed to create tarball."; exit 1; }
    rm -rf "$unpacked_name" "$archive_name"
}

# Build Erlang versions
for version in "${ERLANG_VERSIONS[@]}"; do
    build_erlang \
        "$version" \
        "https://github.com/erlang/otp/releases/download/OTP-${version}/otp_src_${version}.tar.gz" \
        "${BASE_DIR}/erlang@${version}"
done

# Verify Erlang versions
for version in "${ERLANG_VERSIONS[@]}"; do
    "${BASE_DIR}/erlang@${version}/bin/erl" -version
done

# Cleanup
rm -rf "${BASE_DIR}"/*
