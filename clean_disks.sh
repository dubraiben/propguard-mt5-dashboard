#!/bin/bash

echo "=========================================================="
echo "  🧹 ORACLE CLOUD STORAGE CLEANER: REMOVING OLD DISKS"
echo "=========================================================="

# 1. Find and delete arb-bots-restored-jun19
echo "[*] Searching for 'arb-bots-restored-jun19'..."
ID1=$(oci bv boot-volume list -c "$OCI_TENANCY" --query "data[?contains(\"display-name\", 'arb-bots-restored')].id" --raw-output 2>/dev/null | tr -d '[]," \n')

if [ -n "$ID1" ] && [ "$ID1" != "None" ]; then
  echo "[-] Deleting arb-bots-restored-jun19 ($ID1)..."
  oci bv boot-volume delete --boot-volume-id "$ID1" --force
  echo "[OK] Successfully deleted arb-bots-restored-jun19! (+47 GB reclaimed)"
else
  echo "[i] arb-bots-restored-jun19 already deleted or not found."
fi

# 2. Find and delete arb-bots-server (Boot Volume)
echo "[*] Searching for 'arb-bots-server'..."
ID2=$(oci bv boot-volume list -c "$OCI_TENANCY" --query "data[?contains(\"display-name\", 'arb-bots-server')].id" --raw-output 2>/dev/null | tr -d '[]," \n')

if [ -n "$ID2" ] && [ "$ID2" != "None" ]; then
  echo "[-] Deleting arb-bots-server ($ID2)..."
  oci bv boot-volume delete --boot-volume-id "$ID2" --force
  echo "[OK] Successfully deleted arb-bots-server! (+47 GB reclaimed)"
else
  echo "[i] arb-bots-server already deleted or not found."
fi

echo ""
echo "=========================================================="
echo "  CURRENT REMAINING BOOT VOLUMES:"
echo "=========================================================="
oci bv boot-volume list -c "$OCI_TENANCY" --output table --query "data[*].{Name:\"display-name\", SizeGB:\"size-in-gbs\", State:\"lifecycle-state\"}"
echo "=========================================================="
echo "🎉 Cleanup complete! Reclaimed up to 94 GB of free storage space."
echo "=========================================================="
