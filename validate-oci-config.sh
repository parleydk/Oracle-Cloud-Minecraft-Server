#!/usr/bin/env bash
# validate-oci-config.sh -- Validate OCI CLI config and extract root compartment OCID
# Writes root OCID to ~/oci-scripts/root_ocid.txt and logs to ~/oci-scripts/validate.log
set -euo pipefail

SCRIPT_DIR="$HOME/oci-scripts"
LOG_FILE="$SCRIPT_DIR/validate.log"
CONFIG_FILE="$HOME/.oci/config"
ROOT_OCID_FILE="$SCRIPT_DIR/root_ocid.txt"

mkdir -p "$SCRIPT_DIR"

log()  { printf "[INFO] %s\n" "$1" | tee -a "$LOG_FILE"; }
error(){ printf "[ERROR] %s\n" "$1" | tee -a "$LOG_FILE"; exit 1; }

log "Starting OCI config validation..."

# Check oci CLI presence
if ! command -v oci >/dev/null 2>&1; then
  error "OCI CLI not found in PATH. Ensure ~/bin is in PATH and oci is installed."
fi

# Check config file
if [ ! -f "$CONFIG_FILE" ]; then
  error "OCI config file not found at $CONFIG_FILE"
fi
log "Found config file at $CONFIG_FILE"

# Quick connectivity test
if ! oci iam region list >/dev/null 2>>"$LOG_FILE"; then
  error "Failed to connect to OCI. Check ~/.oci/config, API keys, and network connectivity."
fi
log "CLI connectivity OK"

# Extract tenancy OCID from config
TENANCY_OCID="$(grep -E '^tenancy=' "$CONFIG_FILE" | head -n1 | cut -d= -f2- | tr -d '[:space:]')"
if [ -z "$TENANCY_OCID" ]; then
  error "Tenancy OCID not found in config file."
fi
log "Tenancy OCID: $TENANCY_OCID"

# Use tenancy OCID as root compartment OCID and save
echo "$TENANCY_OCID" > "$ROOT_OCID_FILE"
log "Saved root compartment OCID to $ROOT_OCID_FILE"

log "Validation complete."
