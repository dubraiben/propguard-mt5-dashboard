#!/bin/bash

echo "=========================================================="
echo "  🎯 ORACLE FRANKFURT AMPERE CAPACITY AUTO-SNIPER"
echo "=========================================================="
echo "  Target: 2 OCPUs / 12 GB RAM (or 1 OCPU / 6 GB fallback)"
echo "  Region: Germany Central (Frankfurt) [eu-frankfurt-1]"
echo "  Status: Monitoring all 3 Availability Domains..."
echo "=========================================================="
echo ""

ATTEMPT=1
while true; do
  echo ">>> [Attempt #$ATTEMPT] Checking capacity at $(date +%H:%M:%S)..."
  
  # Run the provisioner
  bash <(curl -sSL https://raw.githubusercontent.com/dubraiben/propguard-mt5-dashboard/main/launch.sh)
  
  # Check if an Ampere instance is provisioning or running
  NEW_ID=$(oci compute instance list -c "$OCI_TENANCY" --query "data[?contains(shape, 'A1') && \"lifecycle-state\"!='TERMINATED'].id" --raw-output 2>/dev/null | tr -d '[]," ')
  
  if [ -n "$NEW_ID" ] && [ "$NEW_ID" != "None" ]; then
    echo ""
    echo "=========================================================="
    echo "🎉🎉🎉 SUCCESS! AMPERE INSTANCE SECURED! 🎉🎉🎉"
    echo "Instance ID: $NEW_ID"
    echo "=========================================================="
    break
  fi
  
  ATTEMPT=$((ATTEMPT + 1))
  echo ""
  echo "⏳ Racks are still full. Next attempt in 60s (Press Ctrl+C to stop)..."
  echo "----------------------------------------------------------"
  sleep 60
done
