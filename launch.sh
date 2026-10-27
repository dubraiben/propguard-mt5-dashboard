#!/bin/bash

echo "=========================================================="
echo "  🚀 ORACLE FRANKFURT AD-1 AMPERE AUTO-PROVISIONER"
echo "=========================================================="

# 1. SSH Key
PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDb17hUUWB8EV/QbbXjgSObtOlkPVQV5q6KPiwxxhVCIq+wPBOfPDjDEOggJIHX3IL6BE83PRI/L2Vh7r9O/LOyt8HFE/zDhSXpQNWqJiANvwzcdoauGIPYoOZlqChugyCJWl3DrYtLAz/G0p3wt6wCrwtS2E1/LIeLjuPncHt/snBdyvj2omi70i9nePir+54yOQS5bFb/rmgPBW8+8TPiKbJ3eCeYUVpEgujZ1eadGTR85gNeVcTqiu+JAXwvORbvMxsd0gXbC7rpLlDf6uKbTihZ5YALhEzDlPzrfpUKG6oVhO8LIE52V6N9fLznybzNPjZ2YpREoiVpryDk6qJ5"
echo "$PUB_KEY" > ~/my_key.pub

# 2. Get Tenancy and Existing VM details
TENANCY="$OCI_TENANCY"
INSTANCE_ID=$(oci compute instance list -c "$TENANCY" --query "data[0].id" --raw-output 2>/dev/null)
SUBNET_ID=$(oci compute vnic-attachment list -c "$TENANCY" --instance-id "$INSTANCE_ID" --query "data[0].\"subnet-id\"" --raw-output 2>/dev/null)

if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" = "None" ]; then
  SUBNET_ID=$(oci network subnet list -c "$TENANCY" --query "data[0].id" --raw-output 2>/dev/null)
fi

IMAGE_ID=$(oci compute image list -c "$TENANCY" --operating-system "Canonical Ubuntu" --shape "VM.Standard.A1.Flex" --sort-by TIMECREATED --sort-order DESC --query "data[0].id" --raw-output 2>/dev/null)

AD="qGZo:EU-FRANKFURT-1-AD-1"

# 3. Attempt 2 OCPUs / 12 GB RAM in AD-1
echo "[*] Attempting AD-1 (2 OCPUs, 12 GB RAM)..."
OUT=$(oci compute instance launch \
  --availability-domain "$AD" \
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
  echo "🎉 SUCCESS! Your 12 GB Ampere instance is PROVISIONING in AD-1!"
  echo "=========================================================="
  exit 0
elif echo "$OUT" | grep -q "Out of host capacity"; then
  echo "[-] AD-1 is temporarily full for 2 cores. Trying 1 core / 6 GB..."
else
  echo "[-] Response: $(echo "$OUT" | grep "message" | head -n 1)"
fi

# 4. Attempt 1 OCPU / 6 GB RAM in AD-1
OUT_6GB=$(oci compute instance launch \
  --availability-domain "$AD" \
  --compartment-id "$TENANCY" \
  --shape "VM.Standard.A1.Flex" \
  --shape-config '{"ocpus": 1, "memoryInGBs": 6}' \
  --display-name "MT5-Trading-6GB" \
  --image-id "$IMAGE_ID" \
  --subnet-id "$SUBNET_ID" \
  --ssh-authorized-keys-file ~/my_key.pub \
  --boot-volume-size-in-gbs 100 2>&1) || true

if echo "$OUT_6GB" | grep -q "PROVISIONING"; then
  echo "=========================================================="
  echo "🎉 SUCCESS! Your 6 GB Ampere instance is PROVISIONING in AD-1!"
  echo "=========================================================="
  exit 0
elif echo "$OUT_6GB" | grep -q "Out of host capacity"; then
  echo "[-] AD-1 is currently at peak capacity for 1 core as well."
fi
