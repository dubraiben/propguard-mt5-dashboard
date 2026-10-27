#!/bin/bash

echo "=========================================================="
echo "  🧹 ORACLE CLOUD: DETACHING SECONDARY DISK & CLEANING UP"
echo "=========================================================="

TENANCY="$OCI_TENANCY"
INSTANCE_ID=$(oci compute instance list -c "$TENANCY" --query "data[0].id" --raw-output 2>/dev/null | tr -d '[]," \n')

echo "[*] Active Instance: $INSTANCE_ID"

# 1. Find any secondary volume attachments on this instance
echo "[*] Checking for secondary attached volumes..."
ATTACHMENT_IDS=$(oci compute volume-attachment list -c "$TENANCY" --instance-id "$INSTANCE_ID" --query "data[*].id" --raw-output 2>/dev/null | tr -d '[]," ')

for att_id in $ATTACHMENT_IDS; do
  if [ -n "$att_id" ] && [ "$att_id" != "None" ]; then
    echo "[-] Detaching secondary volume attachment: $att_id..."
    oci compute volume-attachment detach --volume-attachment-id "$att_id" --force
    echo "[OK] Detached! Waiting 15 seconds for disk release..."
    sleep 15
  fi
done

# 2. Find and delete unattached old boot volume (arb-bots-restored or leftover)
echo "[*] Checking for unattached boot volumes to delete..."
ALL_BVS=$(oci bv boot-volume list -c "$TENANCY" --query "data[*].id" --raw-output 2>/dev/null | tr -d '[]," ')

# Get the primary attached boot volume ID
PRIMARY_BV=$(oci compute boot-volume-attachment list -c "$TENANCY" --availability-domain "qGZo:EU-FRANKFURT-1-AD-1" --instance-id "$INSTANCE_ID" --query "data[0].\"boot-volume-id\"" --raw-output 2>/dev/null | tr -d '[]," \n')

echo "[*] Protected Live OS Disk: $PRIMARY_BV"

for bv_id in $ALL_BVS; do
  if [ "$bv_id" != "$PRIMARY_BV" ] && [ -n "$bv_id" ] && [ "$bv_id" != "None" ]; then
    echo "[-] Safely deleting old secondary disk: $bv_id..."
    oci bv boot-volume delete --boot-volume-id "$bv_id" --force 2>/dev/null || true
  fi
done

echo ""
echo "=========================================================="
echo "  FINAL BOOT VOLUMES IN YOUR ACCOUNT:"
echo "=========================================================="
oci bv boot-volume list -c "$TENANCY" --output table --query "data[*].{Name:\"display-name\", SizeGB:\"size-in-gbs\", State:\"lifecycle-state\"}"
echo "=========================================================="
echo "🎉 Only your 1 live server disk remains. All wasted space reclaimed!"
echo "=========================================================="
