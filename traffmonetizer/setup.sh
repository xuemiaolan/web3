#!/bin/bash

TOKEN="+A03Vob43NjqamJhpG2eldeXRUnybSSEOOiP1wfRKzw="

# Install jq if missing
if ! command -v jq >/dev/null 2>&1; then
    apt update -y && apt install -y jq
fi

echo "[1] Detecting architecture..."
ARCH=$(uname -m)

if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    IMAGE="traffmonetizer/cli_v2:arm64v8"
else
    IMAGE="traffmonetizer/cli_v2:latest"
fi

echo "Architecture: $ARCH"
echo "Selected Docker image: $IMAGE"
echo ""

echo "[2] Getting public IP..."
IP=$(curl -s https://api.ipify.org)
if [[ -z "$IP" ]]; then
    echo "Failed to get public IP."
    exit 1
fi
echo "Public IP: $IP"

echo "[3] Fetching IP information..."
INFO=$(curl -s "https://ipinfo.io/${IP}/json")

COUNTRY=$(echo "$INFO" | jq -r '.country')
REGION=$(echo "$INFO" | jq -r '.region')
ORG=$(echo "$INFO" | jq -r '.org')

ISP=$(echo "$ORG" | cut -d' ' -f2- | tr -d ',' | tr ' ' '_')

DEVICE_NAME="${COUNTRY}-${ISP}-${IP}"

echo "Country: $COUNTRY"
echo "Region: $REGION"
echo "ISP: $ISP"
echo "Generated Device Name: $DEVICE_NAME"
echo ""

echo "[4] Checking if Docker container 'tm' exists..."
if docker ps -a --format '{{.Names}}' | grep -q '^tm$'; then
    echo "Container 'tm' already exists. Skipping docker run."
else
    echo "Container 'tm' does not exist. Starting new container..."

    docker run -d \
      --name tm \
      $IMAGE \
      start accept \
      --token "$TOKEN" \
      --device-name "$DEVICE_NAME"

    echo "Container 'tm' started successfully."
fi

echo ""
echo "Final Device Name: $DEVICE_NAME"
echo "Done."

