#!/bin/bash
# Download resources for 1Panel v2 build
# This script replaces ci/script.sh to ensure compatibility across all versions

set -e

INSTALLER_REF="${INSTALLER_REF:-v2}"
INSTALLER_BASE="https://github.com/1Panel-dev/installer/raw/${INSTALLER_REF}"

echo "Using installer ref: ${INSTALLER_REF}"

# Download 1pctl
if [ ! -f "1pctl" ]; then
    echo "Downloading 1pctl..."
    wget -q "${INSTALLER_BASE}/1pctl" -O 1pctl
fi

# Download install.sh
if [ ! -f "install.sh" ]; then
    echo "Downloading install.sh..."
    wget -q "${INSTALLER_BASE}/install.sh" -O install.sh
fi

# Download service files to root directory (required by goreleaser)
echo "Downloading service files..."
wget -q "${INSTALLER_BASE}/initscript/1panel-core.service" -O 1panel-core.service || true
wget -q "${INSTALLER_BASE}/initscript/1panel-agent.service" -O 1panel-agent.service || true

# Download initscript directory
if [ ! -d "initscript" ]; then
    echo "Downloading initscript files..."
    mkdir -p initscript
    for file in 1panel-core.init 1panel-agent.init 1panel-core.openrc 1panel-agent.openrc 1panel-core.procd 1panel-agent.procd 1panel-core.service 1panel-agent.service; do
        wget -q "${INSTALLER_BASE}/initscript/${file}" -O "initscript/${file}" || echo "[WARN] Failed to download ${file}"
    done
fi

# Download lang directory
if [ ! -d "lang" ]; then
    echo "Downloading lang files..."
    mkdir -p lang
    for lang in en fa pt-BR ru zh; do
        wget -q "${INSTALLER_BASE}/lang/${lang}.sh" -O "lang/${lang}.sh" || echo "[WARN] Failed to download ${lang}.sh"
    done
fi

# Download GeoIP.mmdb
if [ ! -f "GeoIP.mmdb" ]; then
    echo "Downloading GeoIP.mmdb..."
    wget -q "https://resource.fit2cloud.com/1panel/package/v2/geo/GeoIP.mmdb" -O GeoIP.mmdb || echo "[WARN] Failed to download GeoIP.mmdb"
fi

chmod 755 1pctl install.sh 2>/dev/null || true

echo "Resources download completed."
