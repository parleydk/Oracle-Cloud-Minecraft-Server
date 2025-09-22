#!/bin/bash
# Oracle Cloud Tenancy Cleanup Script for Parley
# Interactive: choose which resource types to delete after summary

ROOT_OCID=$(cat ~/oci-scripts/root_ocid.txt)
LOG_FILE="$HOME/oci-scripts/cleanup.log"

# --- User Prompts for Flags ---
read -p "Enable dry-run mode? (y/n): " dry_run_choice
DRY_RUN=false
[[ "$dry_run_choice" =~ ^[Yy]$ ]] && DRY_RUN=true

read -p "Enable debug logging? (y/n): " debug_choice
DEBUG=false
[[ "$debug_choice" =~ ^[Yy]$ ]] && DEBUG=true

log() { echo -e "\033[1;34m[INFO]\033[0m $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1" | tee -a "$LOG_FILE"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1" | tee -a "$LOG_FILE"; }

# Function to execute OCI CLI commands
# Appends --debug flag if enabled
delete_resource() {
  local cmd="$1"
  local desc="$2"

  if $DEBUG; then
    cmd="$cmd --debug"
  fi

  if $DRY_RUN; then
    warn "Dry-run: would delete $desc"
  else
    log "Deleting $desc..."
    eval "$cmd" >> "$LOG_FILE" 2>&1
  fi
}

delete_vcn_and_dependencies() {
  # Get VCN IDs and filter for valid OCIDs
  local vcn_ids=$(oci network vcn list --compartment-id $ROOT_OCID --query "data[].id" --raw-output | tr -d '[],"')
  for vcn_id in $vcn_ids; do
    log "🔧 Tearing down VCN $vcn_id"

    # Subnets
    local subnet_ids=$(oci network subnet list --compartment-id $ROOT_OCID --vcn-id $vcn_id --query "data[].id" --raw-output | tr -d '[],"')
    for subnet_id in $subnet_ids; do
      delete_resource "oci network subnet delete --subnet-id $subnet_id --force" "Subnet $subnet_id"
    done

    # Route Tables
    local rt_ids=$(oci network route-table list --compartment-id $ROOT_OCID --vcn-id $vcn_id --query "data[].id" --raw-output | tr -d '[],"')
    for rt_id in $rt_ids; do
      delete_resource "oci network route-table delete --rt-id $rt_id --force" "Route Table $rt_id"
    done

    # Internet Gateways
    local ig_ids=$(oci network internet-gateway list --compartment-id $ROOT_OCID --vcn-id $vcn_id --query "data[].id" --raw-output | tr -d '[],"')
    for ig_id in $ig_ids; do
      delete_resource "oci network internet-gateway delete --ig-id $ig_id --force" "Internet Gateway $ig_id"
    done

    # NAT Gateways
    local nat_ids=$(oci network nat-gateway list --compartment-id $ROOT_OCID --vcn-id $vcn_id --query "data[].id" --raw-output | tr -d '[],"')
    for nat_id in $nat_ids; do
      delete_resource "oci network nat-gateway delete --nat-gateway-id $nat_id --force" "NAT Gateway $nat_id"
    done

    # Service Gateways
    local sg_ids=$(oci network service-gateway list --compartment-id $ROOT_OCID --vcn-id $vcn_id --query "data[].id" --raw-output | tr -d '[],"')
    for sg_id in $sg_ids; do
      delete_resource "oci network service-gateway delete --service-gateway-id $sg_id --force" "Service Gateway $sg_id"
    done

    # Security Lists
    local sl_ids=$(oci network security-list list --compartment-id $ROOT_OCID --vcn-id $vcn_id --query "data[].id" --raw-output | tr -d '[],"')
    for sl_id in $sl_ids; do
      delete_resource "oci network security-list delete --security-list-id $sl_id --force" "Security List $sl_id"
    done

    # DRGs
    local drg_ids=$(oci network drg list --compartment-id $ROOT_OCID --query "data[].id" --raw-output | tr -d '[],"')
    for drg_id in $drg_ids; do
      delete_resource "oci network drg delete --drg-id $drg_id --force" "DRG $drg_id"
    done

    # NSGs - Fix: only process output lines that contain 'ocid1'
    local nsg_ids=$(oci network network-security-group list --compartment-id $ROOT_OCID --vcn-id $vcn_id --query "data[].id" --raw-output | grep "ocid1" | tr -d '[],"')
    for nsg_id in $nsg_ids; do
      delete_resource "oci network network-security-group delete --network-security-group-id $nsg_id --force" "NSG $nsg_id"
    done

    # Finally, delete the VCN
    delete_resource "oci network vcn delete --vcn-id $vcn_id --force" "VCN $vcn_id"
  done
}

log "Starting cleanup for compartment: $ROOT_OCID" [cite: 1]
log "Dry-run mode: $DRY_RUN" [cite: 1]
log "Debug mode: $DEBUG" [cite: 1]

# 🧮 Resource Summary
log "Generating resource summary..." [cite: 1]

COUNT_INSTANCES=$(oci compute instance list --compartment-id $ROOT_OCID --query "data[].id" --raw-output | wc -l)
COUNT_VOLUMES=$(oci bv volume list --compartment-id $ROOT_OCID --query "data[].id" --raw-output | wc -l)
COUNT_VCNS=$(oci network vcn list --compartment-id $ROOT_OCID --query "data[].id" --raw-output | tr -d '[],"' | wc -l)
COUNT_BUCKETS=$(oci os bucket list --compartment-id $ROOT_OCID --query "data[].name" --raw-output | wc -l)
COUNT_ADBS=$(oci db autonomous-database list --compartment-id $ROOT_OCID --query "data[].id" --raw-output | wc -l)
COUNT_LBS=$(oci lb load-balancer list --compartment-id $ROOT_OCID --query "data[].id" --raw-output | wc -l)

echo -e "\n🧾 Resource Summary:"
echo "  1. Compute Instances:        $COUNT_INSTANCES"
echo "  2. Block Volumes:            $COUNT_VOLUMES"
echo "  3. VCNs (with dependencies): $COUNT_VCNS"
echo "  4. Buckets:                  $COUNT_BUCKETS"
echo "  5. Autonomous Databases:     $COUNT_ADBS"
echo "  6. Load Balancers:           $COUNT_LBS"
echo "  7. All of the above"
echo "  8. Abort"
echo ""

read -p "Select which resource types to delete (e.g., 1 3 5 or 7 for all): " CHOICE

if [[ "$CHOICE" == *"8"* ]]; then
  warn "Cleanup aborted by user."
  exit 0
fi

if ! $DRY_RUN; then
  read -p "⚠️  Confirm deletion of selected resources? (yes/no): " CONFIRM
  [[ "$CONFIRM" != "yes" ]] && warn "Cleanup aborted." && exit 0
fi

# 🧹 Conditional Cleanup
[[ "$CHOICE" == *"1"* || "$CHOICE" == *"7"* ]] && for id in $(oci compute instance list --compartment-id $ROOT_OCID --query "data[].id" --raw-output | tr -d '[],"'); do
  delete_resource "oci compute instance terminate --instance-id $id --force" "Compute Instance $id"
done

[[ "$CHOICE" == *"2"* || "$CHOICE" == *"7"* ]] && for id in $(oci bv volume list --compartment-id $ROOT_OCID --query "data[].id" --raw-output | tr -d '[],"'); do
  delete_resource "oci bv volume delete --volume-id $id --force" "Block Volume $id"
done

[[ "$CHOICE" == *"3"* || "$CHOCE" == *"7"* ]] && delete_vcn_and_dependencies

[[ "$CHOICE" == *"4"* || "$CHOICE" == *"7"* ]] && for bucket in $(oci os bucket list --compartment-id $ROOT_OCID --query "data[].name" --raw-output | grep -v "^\s*$" | grep -v "^\[\]" | tr -d '[],"'); do
  delete_resource "oci os bucket delete --bucket-name $bucket --force --compartment-id $ROOT_OCID" "Bucket $bucket"
done

[[ "$CHOICE" == *"5"* || "$CHOICE" == *"7"* ]] && for id in $(oci db autonomous-database list --compartment-id $ROOT_OCID --query "data[].id" --raw-output | tr -d '[],"'); do
  delete_resource "oci db autonomous-database delete --autonomous-database-id $id --force" "Autonomous DB $id"
done

[[ "$CHOICE" == *"6"* || "$CHOICE" == *"7"* ]] && for id in $(oci lb load-balancer list --compartment-id $ROOT_OCID --query "data[].id" --raw-output | tr -d '[],"'); do
  delete_resource "oci lb load-balancer delete --load-balancer-id $id --force" "Load Balancer $id"
done

log "Cleanup complete."
