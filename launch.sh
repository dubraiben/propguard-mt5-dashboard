#!/bin/bash

echo "=========================================================="
echo "  🚀 ORACLE CLOUD AMPERE (12GB / 2 OCPU) AUTO-PROVISIONER"
echo "=========================================================="

# 1. SSH Key
PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDb17hUUWB8EV/QbbXjgSObtOlkPVQV5q6KPiwxxhVCIq+wPBOfPDjDEOggJIHX3IL6BE83PRI/L2Vh7r9O/LOyt8HFE/zDhSXpQNWqJiANvwzcdoauGIPYoOZlqChugyCJWl3DrYtLAz/G0p3wt6wCrwtS2E1/LIeLjuPncHt/snBdyvj2omi70i9nePir+54yOQS5bFb/rmgPBW8+8TPiKbJ3eCeYUVpEgujZ1eadGTR85gNeVcTqiu+JAXwvORbvMxsd0gXbC7rpLlDf6uKbTihZ5YALhEzDlPzrfpUKG6oVhO8LIE52V6N9fLznybzNPjZ2YpREoiVpryDk6qJ5"
echo "$PUB_KEY" > ~/my_key.pub
echo "[OK] SSH Key saved to ~/my_key.pub"

# 2. Get Tenancy and Existing VM details
TENANCY="$OCI_TENANCY"
echo "[*] Discovering network and existing VM details..."
INSTANCE_ID=$(oci compute instance list -c "$TENANCY" --query "data[0].id" --raw-output 2>/dev/null)
SUBNET_ID=$(oci compute vnic-attachment list -c "$TENANCY" --instance-id "$INSTANCE_ID" --query "data[0].\"subnet-id\"" --raw-output 2>/dev/null)

if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" = "None" ]; then
  SUBNET_ID=$(oci network subnet list -c "$TENANCY" --query "data[0].id" --raw-output 2>/dev/null)
fi

echo "    Subnet ID: $SUBNET_ID"

echo "[*] Finding latest Ubuntu Arm64 (aarch64) Image..."
IMAGE_ID=$(oci compute image list -c "$TENANCY" --operating-system "Canonical Ubuntu" --shape "VM.Standard.A1.Flex" --sort-by TIMECREATED --sort-order DESC --query "data[0].id" --raw-output 2>/dev/null)
echo "    Image ID : $IMAGE_ID"

if [ -z "$IMAGE_ID" ] || [ "$IMAGE_ID" = "None" ]; then
  echo "[ERR] Could not find Ubuntu image for VM.Standard.A1.Flex."
  exit 1
fi

# 3. Try each Availability Domain
ADS=("qGZo:EU-FRANKFURT-1-AD-2" "qGZo:EU-FRANKFURT-1-AD-3" "qGZo:EU-FRANKFURT-1-AD-1")

SUCCESS=0
for ad in "${ADS[@]}"; do
  echo ""
  echo "[*] Attempting launch in: $ad (2 OCPUs, 12 GB RAM)..."
  OUT=$(oci compute instance launch \
    --availability-domain "$ad" \
    --compartment-id "$TENANCY" \
    --shape "VM.Standard.A1.Flex" \
    --shape-config '{"ocpus": 2, "memoryInGBs": 12}' \
    --display-name "MT5-Trading-12GB" \
    --image-id "$IMAGE_ID" \
    --subnet-id "$SUBNET_ID" \
    --ssh-authorized-keys-file ~/my_key.pub \
    --boot-volume-size-in-gbs 100 2>&1) || true

  if echo "$OUT" | grep -q "PROVISIONING"; then
    echo "=========================================================="
    echo "🎉 SUCCESS! Your 12 GB Ampere instance is PROVISIONING in $ad!"
    echo "=========================================================="
    SUCCESS=1
    break
  elif echo "$OUT" | grep -q "Out of host capacity"; then
    echo "[-] $ad is temporarily out of host capacity. Trying next AD..."
  else
    echo "Response: $OUT"
  fi
done

if [ $SUCCESS -eq 0 ]; then
  echo ""
  echo "[*] Frankfurt is in peak demand for 2 cores. Trying 1 OCPU / 6 GB RAM in all ADs..."
  for ad in "${ADS[@]}"; do
    echo "[-] Attempting $ad (1 OCPU, 6 GB RAM)..."
    OUT=$(oci compute instance launch \
      --availability-domain "$ad" \
      --compartment-id "$TENANCY" \
      --shape "VM.Standard.A1.Flex" \
      --shape-config '{"ocpus": 1, "memoryInGBs": 6}' \
      --display-name "MT5-Trading-6GB" \
      --image-id "$IMAGE_ID" \
      --subnet-id "$SUBNET_ID" \
      --ssh-authorized-keys-file ~/my_key.pub \
      --boot-volume-size-in-gbs 100 2>&1) || true

    if echo "$OUT" | grep -q "PROVISIONING"; then
      echo "=========================================================="
      echo "🎉 SUCCESS! Your 6 GB Ampere instance is PROVISIONING in $ad!"
      echo "=========================================================="
      SUCCESS=1
      break
    fi
  done
fi

if [ $SUCCESS -eq 0 ]; then
  echo ""
  echo "=========================================================="
  echo "All 3 data centers in Frankfurt are temporarily at peak capacity."
  echo "To automatically keep trying until a spot opens up, run:"
  echo "while true; do bash launch.sh && break; sleep 60; done"
  echo "=========================================================="
fi
