#!/usr/bin/env bash
# setup-oci-cli.sh -- Install and configure OCI CLI on Fedora (as used in this session)
# Usage: bash ~/oci-scripts/setup-oci-cli.sh
set -euo pipefail

# Variables
SCRIPTDIR="$HOME/oci-scripts"
INSTALLER_URL="https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh"
PROFILE_FILE="${HOME}/.bashrc"  # change to ~/.zshrc if you use zsh

mkdir -p "$SCRIPTDIR"

echo
echo "1) Installing system dependencies (python3, pip, unzip, python3-devel)..."
sudo dnf install -y python3 python3-pip unzip python3-devel

echo
echo "2) Downloading and running OCI CLI installer (interactive)."
echo "   If you prefer fully automated defaults, re-run the installer with --accept-all-defaults."
bash -c "$(curl -L ${INSTALLER_URL})"

echo
echo "3) Ensure ~/bin is in PATH for current session and future shells."
grep -qxF 'export PATH=$HOME/bin:$PATH' "$PROFILE_FILE" || echo 'export PATH=$HOME/bin:$PATH' >> "$PROFILE_FILE"
export PATH="$HOME/bin:$PATH"

echo
echo "4) Verify oci CLI is available and show version."
if command -v oci >/dev/null 2>&1; then
  oci --version
else
  echo "[ERROR] oci not found in PATH after installer. Check $PROFILE_FILE and restart your shell."
  exit 1
fi

echo
echo "5) Launching interactive OCI CLI configuration (oci setup config)."
echo "   This will prompt for user OCID, tenancy OCID, region, and API key generation."
echo "   Follow the prompts; your keys and ~/.oci/config will be created."
oci setup config

echo
echo "6) Quick verification: list accessible regions (should return regions for your tenancy)."
oci iam region-subscription list --query "data[].region-name" --raw-output

echo
echo "Done. If you generated keys, remember to upload the public key (~/.oci/oci_api_key_public.pem) in the Console under Identity > Users > <your user> > API Keys."
echo "Your OCI CLI is installed and configured. Scripts can be placed in $SCRIPTDIR."
